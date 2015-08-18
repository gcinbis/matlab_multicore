function [resultCell] = startmulticoremaster(functionHandleCell, parameterCell, settings)
% resultCell = startmulticoremaster(functionHandleCell, parameterCell, settings)
%
% The loop
%   for k=1:numel(PARAMETERCELL)
%       RESULTCELL{k} = FHANDLE(PARAMETERCELL{k}{:}); % if PARAMETERCELL{k} is a cell array
%   OR
%       RESULTCELL{k} = FHANDLE(PARAMETERCELL{k});    % if PARAMETERCELL{k} is not a cell array
%   end
% is done via multiprocessing using startmulticoreslave()
%
% INPUT
% functionHandleCell
% parameterCell
% settings
%   [multicoreDir]      Name of the directory for temporary files is given by
%                       multicoredirs(multicoreDir). For example,
%                       multicoreDir='local' for working on /dev/shm/username/multicore..
%   [multicoreDirPath]  Full path of the multicore directory.
%   [nrOfEvalsAtOnce]   Number of function evaluations gathered to a single job. (def=1)
%   [maxEvalTimeSingle] Timeout for a single function evaluation in seconds. Choose this
%                       parameter appropriately to get optimum performance. (def=inf)
%   [masterIsWorker]    If true, master process acts as worker and coordinator, if
%                       false the master acts only as coordinator. (def=true)
%   [disablemc]         (def=false) If true, a simple for loop is used instead.
%   [keyboard]          (def=false) If true, on error (in master or slave), master goes into
%                       keyboard, allowing manual error recovery. 
%
% OUTPUT
% [resultCell]          If resultCell is request, each function will be called as "result = func(...)".
%                       Otherwise, function calls will be just "func(...)".     
%
% Notes:
% - Randomization is internal, doesnt interfere with the global rand state.
% - When master is interrupted (ctrl-c) or a job fails completely, it automatically deletes all job-related files.
% - If there is a an error/MException thrown at a slave, it will be catched and reported back to the master.
%   But, 
%       - if you CTRL-C on a slave (not an MException)
%       - if you "dbquit" within a job which called "keyboard" on a slave (not an MException)
%       - kill the slave and manually delete its working file (but not the corresponding param file!)
%   another slave (or master) will restart on the interrupted job. So, main job will not be
%   affected. This way one can also fix the implementation errors effective only few jobs.
% - Two good and clean ways to handle random errors (those that arent due to bugs) like out-of-memory:
%   1) Always run master in masterIsWorker=false. In this way, the actual process cannot be harmed due to errors
%   and once can always kill/manage the slaves easily as needed. Note that handling a crash in the master is
%   too inefficient to handle.
%   2) Always put try-catch-keyboard around the slave job. If a random error is generated, one can
%   simply say "dbquit", which will recreate the job while stopping that slave.
%
% A customization by Gokberk Cinbis of the multicore package by Markus Buehren. The base version is "Last Modified
% 10.03.2010" 
%
% See also startmulticoreslave multicoredirs 
%

% todo/ideas: 
% * handle MATLAB:nomem differently such that the job will be recreated after waiting
% * copy all diary output to the master.
% * "shared variables" to reduce I/O overhead.
% * tcp based communication
% * use system handlers or write a utility to check if the corresponding process is actually working
% at the host that it says it does.


% default settings
cn_setvardefaults(true,'settings',[]);
settings = cn_setfielddefaults(settings,false,...
    'multicoreDir','','nrOfEvalsAtOnce',1,'maxEvalTimeSingle',inf,...
    'masterIsWorker',true,'useWaitbar',0,...
    'disablemc',false,'keyboard',false,'spec','');

if isempty(parameterCell)
    multicore_warn('multicore: parameterCell is empty!');
    if nargout > 0
        resultCell = {};
    end
    return;
end

% check function handle cell
if isa(functionHandleCell, 'function_handle')
    % expand to cell array
    functionHandleCell = repmat({functionHandleCell}, size(parameterCell));
else
    if ~iscell(functionHandleCell)
        error('First input argument must be a function handle or a cell array of function handles.');
    elseif any(size(functionHandleCell) ~= size(parameterCell))
        error('Input cell arrays functionHandleCell and parameterCell must be of the same size.');
    end
end

cn_timepassth('startmulticoremaster',0);

% GOKBERK
if (settings.disablemc) || ...
        ((length(parameterCell) <= 1) && settings.masterIsWorker) || ...
        ((length(parameterCell) <= settings.nrOfEvalsAtOnce) && settings.masterIsWorker) 
    if (length(parameterCell) > 1) && settings.disablemc
        disp('multiprocessing is disabled by settings.disablemc.');
    end

    if nargout > 0
        resultCell = cell(1,length(parameterCell));
    end
    for j = 1:length(parameterCell)
        if cn_timepassth('startmulticoremaster')
            multicore_warn(sprintf('master is calling for %d/%d\n',j,length(parameterCell)));
        end
        if settings.keyboard
            if nargout > 0
                resultCell = irunmaster(functionHandleCell,parameterCell,resultCell,j,settings);
            else
                irunmaster(functionHandleCell,parameterCell,[],j,settings);
            end
        else
            % better to keep things simple
            if iscell( parameterCell{j} )
                if nargout > 0
                    resultCell{j} = functionHandleCell{j}(parameterCell{j}{:});
                else
                    functionHandleCell{j}(parameterCell{j}{:});
                end
            else
                if nargout > 0
                    resultCell{j} = functionHandleCell{j}(parameterCell{j});
                else
                    functionHandleCell{j}(parameterCell{j});
                end
            end
        end
    end
    return;
end

if ~(settings.masterIsWorker)
    multicore_warn('masterIsWorker=false');
end

debugMode    = 0;
showWarnings = 1;

% parameters
startPauseTime = 0.1;
maxPauseTime   = 2;

if debugMode
    disp(sprintf('*********** Start of function %s **********', mfilename));
    startTime    = mbtime;
    showWarnings = 1;
    setTime      = 0;
    removeTime   = 0;
end

% Initialize waitbar
assert(~settings.useWaitbar); % GOKBERK not supported anymore to concentrate on the actual work.

%%%%%%%%%%%%%%%%
% check inputs %
%%%%%%%%%%%%%%%%
error(nargchk(2, 3, nargin, 'struct'))

% check parameter cell
if ~iscell(parameterCell)
    error('Second input argument must be a cell array.');
end

% check number of evaluations at once
nrOfEvals = numel(parameterCell);
nrOfEvalsAtOnce = settings.nrOfEvalsAtOnce;
if nrOfEvalsAtOnce > nrOfEvals
    nrOfEvalsAtOnce = nrOfEvals;
elseif nrOfEvalsAtOnce < 1
    error('Parameter nrOfEvalsAtOnce must be greater or equal one.');
end
nrOfEvalsAtOnce = round(nrOfEvalsAtOnce);

% check slave file directory
if isfield(settings,'multicoreDirPath')
    multicoreDir = settings.multicoreDirPath; % overrides multicoreDir option.
else
    if isempty(settings.multicoreDir)
        % create default slave file directory if not existing
        %multicoreDir = fullfile(tempdir2, 'multicorefiles');
        multicoreDir = multicoredirs(); 
        multicoreDir = multicoreDir{1}; % default directory.
    else
        multicoreDir = multicoredirs(settings.multicoreDir);
    end
end
if ~exist(multicoreDir, 'dir')
    error('Slave file directory %s not existing.', multicoreDir);
end

% check maxEvalTimeSingle
maxEvalTimeSingle = settings.maxEvalTimeSingle;
if maxEvalTimeSingle < 0
    error('Parameter maxEvalTimeSingle must be greater or equal zero.');
end

% compute the maximum waiting time for a complete job
maxMasterWaitTime = maxEvalTimeSingle * nrOfEvalsAtOnce;

% compute number of files/jobs
nrOfFiles = ceil(nrOfEvals / nrOfEvalsAtOnce);
if debugMode
    disp(sprintf('nrOfFiles = %d', nrOfFiles));
end

% DONT remove all existing temporary multicore files
existingMulticoreFiles = [...
    findfiles(multicoreDir, 'parameters_*.mat', 'nonrecursive'), ...
    findfiles(multicoreDir, 'working_*.mat',    'nonrecursive'), ...
    findfiles(multicoreDir, 'result_*.mat',     'nonrecursive')];
% deletewithsemaphores(existingMulticoreFiles);
% GOKBERK: NO, MAY BE THERE ARE MULTIPLE MASTERS!
%for gokberk_i = 1:length(existingMulticoreFiles)
%    fprintf('%s: %s \n','EXISTS: [NOT DELETED]',existingMulticoreFiles{gokberk_i});
%end

% build parameter file name (including the date is important because slave
% processes might still be working with old parameters)
%dateStr = sprintf('%04d%02d%02d%02d%02d%02d', round(clock));

% do want it to be too long!
dateStr = multicore_myidstr(1,1,1); % use the safest option!
dateStr = strrep(dateStr,'-','');
dateStr = strrep(dateStr,'_','');
dateStr = strrep(dateStr,'.','');
dateStr = dateStr(7:end); % skip year, month, etc.
%extra.dateStr = dateStr;

parameterFileNameTemplate = fullfile(multicoreDir, sprintf('parameters_%s_XX.mat', dateStr));

% GOKBERK
fprintf('JOBS: %s\n',strrep(parameterFileNameTemplate,'XX','*'));

% will delete all related files on interrupt
cleanupobj = multicore_onCleanup( @() cleanup_files(multicoreDir,dateStr) );

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% generate parameter files %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% internal options
internal.spec = settings.spec;
internal.nargout = nargout;

% save parameter files with all parameter sets
for lastFileNrMaster = nrOfFiles:-1:1
    curFileNr = lastFileNrMaster; % for simpler copy&paste
    parameterFileName = strrep(parameterFileNameTemplate, 'XX', sprintf('%04d', curFileNr));
    parIndex = ((curFileNr-1)*nrOfEvalsAtOnce+1) : min(curFileNr*nrOfEvalsAtOnce, nrOfEvals);
    functionHandles = functionHandleCell(parIndex); %#ok
    parameters      = parameterCell     (parIndex); %#ok

    if debugMode, 
        t1 = mbtime; 
    end
    sem = setfilesemaphore(parameterFileName);
    if debugMode,
        setTime = setTime + mbtime - t1; 
    end

    try
        gokberk_save_master(parameterFileName,functionHandles,parameters,internal);

        if debugMode
            disp(sprintf('Parameter file nr %d generated.', curFileNr));
        end
    catch
        if showWarnings
            disp(textwrap2(sprintf('Warning: Unable to save file %s.', parameterFileName)));
            displayerrorstruct;
        end
    end

    if debugMode,
        t1 = mbtime; 
    end
    removefilesemaphore(sem);
    if debugMode,
        removeTime = removeTime + mbtime - t1; 
    end

end

if internal.nargout > 0
    resultCell = cell(size(parameterCell));
end

lastFileNrMaster = 1;         % start working down the list from top to bottom
lastFileNrSlave = nrOfFiles; % check for results from bottom to top
parameterFileFoundTime  = NaN;
parameterFileRegCounter = 0;
nrOfFilesMaster = 0;
nrOfFilesSlaves = 0;

% Call "clear functions" to ensure that the latest file versions are used,
% no older versions in Matlab's memory.
clear functions

firstRun = true;
masterIsWorker = settings.masterIsWorker;
while 1 % this while-loop will be left if all work is done
    if masterIsWorker && ~firstRun
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % work down the file list from top %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if debugMode
            disp(sprintf('********** 1. Working from top to bottom (file nr %d)', lastFileNrMaster));
        end
        curFileNr = lastFileNrMaster; % for simpler copy&paste
        parameterFileName = strrep(parameterFileNameTemplate, 'XX', sprintf('%04d', curFileNr));
        resultFileName    = strrep(parameterFileName, 'parameters', 'result' );
        workingFileName   = strrep(parameterFileName, 'parameters', 'working');
        parIndex = ((curFileNr-1)*nrOfEvalsAtOnce+1) : min(curFileNr*nrOfEvalsAtOnce, nrOfEvals);

        if debugMode,
            t1 = mbtime; 
        end
        sem = setfilesemaphore(parameterFileName);
        if debugMode,
            setTime = setTime + mbtime - t1; 
        end

        resultLoaded = false;
        % parameterFileExisting = existfile(parameterFileName);
        parameterFileExisting = existfile(parameterFileName) & ~existfile(workingFileName); % GOKBERK use workingFile to indicate
        if parameterFileExisting
            % If the parameter file is existing, no other process has started
            % working on that job --> Remove parameter file, so that no slave
            % process can load it. The master will do the current job.
            mbdelete(parameterFileName, showWarnings);
            if debugMode
                disp(sprintf('Parameter file nr %d deleted by master.', curFileNr));
            end

            % If the master has taken the parameter file, there is no need to check
            % for a result. Semaphore will be removed below.
            if debugMode 
                disp(sprintf('Not checking for result because parameter file nr %d was existing.', curFileNr));
            end

        else
            % check if the current parameter set was evaluated before by a slave process

            % Another process has taken the parameter file. This branch is
            % entered if master and slave "meet in the middle", i.e. if a slave
            % has taken the parameter file of the job the master would have done
            % next. In this case, the master will wait until the job was finished
            % by the slave process or until the job has timed out.
            curPauseTime = startPauseTime;
            firstRun = true;
            while 1 % this while-loop will be left if result was loaded or job timed out
                if firstRun
                    % use the semaphore generated above
                    firstRun = false;
                else
                    % set semaphore
                    if debugMode,
                        t1 = mbtime; 
                    end
                    sem = setfilesemaphore(parameterFileName);
                    if debugMode,
                        setTime = setTime + mbtime - t1; 
                    end
                end

                % GOKBERK: Changed: Dont attempt reading the file until working file
                % is deleted. Otherwise, we sometimes end up trying to read the file before it is fully 
                % written to the disk.

                % Check if the processing time (current time minus time stamp of
                % working file) exceeds the maximum wait time. Still using the
                % semaphore of the parameter file from above.
                if existfile(workingFileName)
                    if debugMode
                        disp(sprintf('Master found working file nr %d.', curFileNr));
                    end

                    % Check if the job timed out by getting the time when the slave
                    % started working on that file. If the job has timed out, the
                    % master will do the job.
                    jobTimedOut = mbtime - getfiledate(workingFileName) * 86400 > maxMasterWaitTime;
                    
                elseif existfile(resultFileName)

                    % Check if the result is available. The semaphore file of the
                    % parameter file is used for the following file accesses of the
                    % result file.
                    [result, resultLoaded] = loadResultFile(resultFileName, workingFileName,  showWarnings,settings);
                    if resultLoaded && debugMode
                        disp(sprintf('Result file nr %d loaded.', curFileNr));
                    end

                    if resultLoaded
                        % Save result

                        if internal.nargout > 0
                            resultCell(parIndex) = result;
                        end
                        nrOfFilesSlaves = nrOfFilesSlaves + 1;

                        % Leave while-loop immediately after result was loaded. Semaphore
                        % will be removed below.
                        break
                    end

                else
                    % No working file or result file has been found. The loop is immediately left
                    % and the master will do the job.
                    if showWarnings || 1
                        disp(sprintf('Warning: Working file %s not found.', workingFileName));
                        ls(multicoreDir);
                    end
                    jobTimedOut = true;
                end

                if jobTimedOut 
                    if debugMode || 1
                        disp(sprintf('Job nr %d has timed out. (working file is too old)', curFileNr));
                        multicore_warn('gokberk: this shouldnt happen unless I kill the slave!');
                    end
                    % As the slave process seems to be dead or too slow, the master
                    % will do the job itself (semaphore will be removed below).
                    break
                else
                    if debugMode
                        disp(sprintf('Job nr %d has NOT timed out.', curFileNr));
                    end
                end

                % If the job did not time out, remove semaphore and wait a moment
                % before checking again
                if debugMode,
                    t1 = mbtime; 
                end
                removefilesemaphore(sem);
                if debugMode,
                    removeTime = removeTime + mbtime - t1; 
                end

                if debugMode
                    disp(sprintf('Waiting for result (file nr %d).', curFileNr));
                end

                pause(curPauseTime);
                curPauseTime = min(maxPauseTime, curPauseTime + startPauseTime);
            end % while 1
        end % if parameterFileExisting

        % remove semaphore
        if debugMode,
            t1 = mbtime; 
        end
        removefilesemaphore(sem);
        if debugMode,
            removeTime = removeTime + mbtime - t1; 
        end

        % evaluate function if the result could not be loaded
        if ~resultLoaded
            disp(sprintf('Master evaluates job nr %d.', curFileNr)); % useful
            if debugMode 
                t0 = mbtime;
            end
            for k = parIndex
                if debugMode
                    %fprintf(' %d,', k);
                end

                if internal.nargout > 0
                    resultCell = irunmaster(functionHandleCell,parameterCell,resultCell,k,settings);
                else
                    irunmaster(functionHandleCell,parameterCell,[],k,settings);
                end

            end
            nrOfFilesMaster = nrOfFilesMaster + 1;

            if debugMode 
                disp(sprintf('Master finished job nr %d in %.2f seconds.', curFileNr, mbtime - t0));
            end
        end

        % move to next file
        lastFileNrMaster = lastFileNrMaster + 1;
        if debugMode
            disp(sprintf('Moving to next file (%d -> %d).', curFileNr, curFileNr + 1));
        end

    end % if masterIsWorker

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Check if all work is done %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % (lastFileNrMaster - 1) is the number of the file/job that was last computed/loaded when
    % working down the list from top to bottom.
    % (lastFileNrSlave + 1) is the number of the file/job that was last computed/loaded when
    % checking for results from bottom to top.
    if (lastFileNrMaster - 1) + 1 == (lastFileNrSlave + 1)
        % all results have been collected, leave big while-loop
        if debugMode
            disp('********************************');
            disp(sprintf('All work is done (lastFileNrMaster = %d, lastFileNrSlave = %d).', lastFileNrMaster, lastFileNrSlave));
        end
        break
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % work down the file list from bottom to top and collect results %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if debugMode
        disp(sprintf('********** 2. Working from bottom to top (file nr %d)', lastFileNrSlave));
    end

    curPauseTime = startPauseTime;
    while 1 % in this while-loop, lastFileNrSlave will be decremented if results are found
        if lastFileNrSlave < 1
            % all work is done
            if debugMode
                disp('********************************');
                disp(sprintf('All work is done (lastFileNrSlave = %d).', lastFileNrSlave));
            end
            break
        end

        curFileNr = lastFileNrSlave; % for simpler copy&paste
        parameterFileName = strrep(parameterFileNameTemplate, 'XX', sprintf('%04d', curFileNr));
        resultFileName    = strrep(parameterFileName, 'parameters', 'result' );
        workingFileName   = strrep(parameterFileName, 'parameters', 'working');
        parIndex = ((curFileNr-1)*nrOfEvalsAtOnce+1) : min(curFileNr*nrOfEvalsAtOnce, nrOfEvals);

        % set semaphore (only for the parameter file to reduce overhead)
        if debugMode,
            t1 = mbtime; 
        end
        sem = setfilesemaphore(parameterFileName);
        if debugMode,
            setTime = setTime + mbtime - t1; 
        end

        % Check if the result is available (the semaphore file of the
        % parameter file is used for the following file accesses of the
        % result file)
        if existfile(resultFileName)
            [result, resultLoaded] = loadResultFile(resultFileName, workingFileName, showWarnings,settings);
            if resultLoaded && (debugMode || 1)
                disp(sprintf('Result file nr %d loaded.', curFileNr));
            end
        else
            resultLoaded = false;
            if debugMode
                disp(sprintf('Result file nr %d was not found.', curFileNr));
            end
        end
    
        if resultLoaded % GOKBERK
            if length(parIndex) ~= length(result)
                multicore_warn('something is wrong!!!');
                keyboard
                resultLoaded=false; % suggested
            end

            % Result was successfully loaded. Remove semaphore.
            if debugMode, 
                t1 = mbtime; 
            end
            removefilesemaphore(sem);
            if debugMode, 
                removeTime = removeTime + mbtime - t1; 
            end

            % Save result
            if internal.nargout > 0
                resultCell(parIndex) = result;
            end
            nrOfFilesSlaves = nrOfFilesSlaves + 1;

            % Reset variables
            parameterFileFoundTime = NaN;
            curPauseTime = startPauseTime;
            parameterFileRegCounter = 0;

            % Decrement lastFileNrSlave
            lastFileNrSlave = lastFileNrSlave - 1;

            % Check if all work is done
            if (lastFileNrMaster - 1) + 1 == (lastFileNrSlave + 1)
                % all results have been collected
                break
            else
                if debugMode
                    disp(sprintf('***** Moving to next file (%d -> %d).', curFileNr, curFileNr-1));
                end

                % move to next file
                continue
            end

        else
            % Result was not available.

            % Check if parameter file is existing.
            % parameterFileExisting = existfile(parameterFileName);
            parameterFileExisting = existfile(parameterFileName) & ~exist(workingFileName);

            % Check if job timed out.
            if parameterFileExisting
                if debugMode
                    disp(sprintf('Parameter file nr %d was existing.', curFileNr));
                end

                % If the parameter file is existing, no other process has started
                % working on that job yet, which is most of the times normal.
                if ~isnan(parameterFileFoundTime)
                    % If parameterFileFoundTime is not NaN, the same parameter file
                    % has been found before. Now check if the job has timed out,
                    % i.e. no slave process seems to be alive.
                    jobTimedOut = mbtime - parameterFileFoundTime > maxMasterWaitTime;
                else
                    % Remember the current time to decide later if the job has timed out.
                    parameterFileFoundTime = mbtime;
                    jobTimedOut = false;
                end
            else
                if debugMode
                    disp(sprintf('Parameter file nr %d was NOT existing.', curFileNr));
                end

                % Parameter file has been taken by a slave, who should be working
                % on the job.
                if existfile(workingFileName)
                    if debugMode
                        disp(sprintf('Master found working file nr %d.', curFileNr));
                    end
                    % Check if the job has timed out using the time stamp of the
                    % working file.
                    jobTimedOut = mbtime - getfiledate(workingFileName) * 86400 > maxMasterWaitTime;
                else
                    % Parameter file has been taken but no working file has been
                    % generated, which is not normal. The master will generate the
                    % parameter file again or do the job.
                    if showWarnings
                        disp(sprintf('Warning: Working file %s not found.', workingFileName));
                    end
                    jobTimedOut = true;
                end
            end % if parameterFileExisting

            % Do the job or generate parameter file again if job has timed out.
            if jobTimedOut
                if debugMode || 1
                    disp(sprintf('Job nr %d has timed out (q).', curFileNr));
                end

                if parameterFileExisting
                    % The job timed out and the parameter file was existing, so
                    % something seems to be wrong. A possible reason is that no
                    % slaves are alive anymore. The master will do the job.

                    % Remove parameter file so that no other slave process can load it.
                    mbdelete(parameterFileName, showWarnings);
                    if debugMode
                        disp(sprintf('Parameter file nr %d deleted by master.', curFileNr));
                    end
                else
                    % The job timed out and the parameter file was not existing.
                    % A possible reason is that a slave process was killed while
                    % working on the current job (if a slave is still working on
                    % the job and is just too slow, the parameter maxEvalTimeSingle
                    % should be chosen higher). The parameter file is generated
                    % again, hoping that another slave will finish the job. If all
                    % slaves are dead, the master will later do the job.
                    functionHandles = functionHandleCell(parIndex); %#ok
                    parameters      = parameterCell     (parIndex); %#ok
                    try
                        gokberk_save_master(parameterFileName,functionHandles,parameters);
                        if debugMode || 1
                            disp(sprintf('Parameter file nr %d was generated again (%d. time).', ...
                                curFileNr, parameterFileRegCounter));
                        end
                    catch
                        if showWarnings
                            disp(textwrap2(sprintf('Warning: Unable to save file %s.', parameterFileName)));
                            displayerrorstruct;
                        end
                    end
                    parameterFileRegCounter = parameterFileRegCounter + 1;
                end

                % Remove semaphore.
                if debugMode, 
                    t1 = mbtime; 
                end
                removefilesemaphore(sem);
                if debugMode, 
                    removeTime = removeTime + mbtime - t1; 
                end

                if parameterFileExisting  || parameterFileRegCounter > 2
                    % The current job has timed out and the parameter file was not
                    % generated again OR the same parameter file has been
                    % re-generated several times ==> The master will do the job.
                    if debugMode || 1
                        disp(sprintf('Master evaluates job nr %d.', curFileNr));
                        t0 = mbtime;
                    end
                    for k = parIndex

                        if internal.nargout > 0
                            resultCell = irunmaster(functionHandleCell,parameterCell,resultCell,k,settings);
                        else
                            irunmaster(functionHandleCell,parameterCell,[],k,settings);
                        end

                    end
                    nrOfFilesMaster = nrOfFilesMaster + 1;

                    if debugMode
                        disp(sprintf('Master finished job nr %d in %.2f seconds.', curFileNr, mbtime - t0));
                    end

                    % Result has been computed, move to next file
                    lastFileNrSlave = lastFileNrSlave - 1;

                    % Reset number of times the current parameter file was generated
                    % again
                    parameterFileRegCounter = 0;

                    if debugMode
                        disp(sprintf('Moving to next file (%d -> %d).', curFileNr, curFileNr-1));
                    end
                else
                    % The parameter file has been generated again. The master does
                    % not do the job, lastFileNrSlave is not decremented.
                end % if ~parameterFileExisting

                % reset variables
                parameterFileFoundTime = NaN;
                curPauseTime = startPauseTime;
            else
                if debugMode
                    disp(sprintf('Job nr %d has NOT timed out.', curFileNr));
                end

                % Remove semaphore.
                if debugMode, 
                    t1 = mbtime; 
                end
                removefilesemaphore(sem);
                if debugMode, 
                    removeTime = removeTime + mbtime - t1; 
                end

                if ~masterIsWorker
                    % If the master is only coordinator, wait some time before
                    % checking again
                    if debugMode
                        disp(sprintf('Coordinator is waiting %.2f seconds', curPauseTime));
                    end
                    pause(curPauseTime);
                    curPauseTime = min(maxPauseTime, curPauseTime + startPauseTime);
                end
            end % if jobTimedOut

            if masterIsWorker
                % If the master is also a worker, leave the while-loop if the
                % result has not been loaded. Either the job timed out and was done
                % by the master or the job has not been finished yet but is also
                % not timed out, which is normal.
                break
            else
                % If the master is only coordinator, stay in the while-loop.
            end

        end % if resultLoaded
    end % while 1

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Check if all work is done %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % (see comment between the two while-loops)
    if (lastFileNrMaster - 1) + 1 == (lastFileNrSlave + 1)
        % all results have been collected, leave big while-loop
        if debugMode
            disp('********************************');
            disp(sprintf('All work is done (lastFileNrMaster = %d, lastFileNrSlave = %d).', lastFileNrMaster, lastFileNrSlave));
        end
        break
    end

    firstRun = false;
end % while 1

% job is completed, nothing to cleanup
cleanupobj.task = [];

if debugMode
    disp(sprintf('\nSummary:\n--------'));
    disp(sprintf('%2d jobs at all',         nrOfFiles));
    disp(sprintf('%2d jobs done by master', nrOfFilesMaster));
    disp(sprintf('%2d jobs done by slaves', nrOfFilesSlaves));
    %disp('No jobs done by slaves. (Note: You need to run function startmulticoreslave.m in another Matlab session?)');

    overallTime = mbtime - startTime;
    disp(sprintf('Processing took %.1f seconds.', overallTime));
    disp(sprintf('Overhead caused by setting  semaphores: %.1f seconds (%.1f%%).', ...
        setTime,    100*setTime    / overallTime));
    disp(sprintf('Overhead caused by removing semaphores: %.1f seconds (%.1f%%).', ...
        removeTime, 100*removeTime / overallTime));
    disp(sprintf('\n*********** End of function %s **********', mfilename));
end

end % function startmulticoremaster

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [result, resultLoaded] = loadResultFile(resultFileName, workingFileName, showWarnings, settings)

% It is better to attempt reading a file a few times in case of an I/O problem.
MAXWAIT = 60;
SINGLEWAIT = 3;

% reset warnings and errors
lastwarn('');
lasterror('reset');

resultLoaded = false;
q_firsttry = tic;
while(~resultLoaded) 
    % try to load file
    try
        result = []; % (only for M-Lint)
        result_iserr = []; % GOKBERK
        load(resultFileName, 'result','result_iserr'); %% file access %%
        resultLoaded = true;
    catch %#ok
        if showWarnings
            disp(sprintf('Warning: Unable to load file %s.', resultFileName));
        end

        q_cumtry = toc(q_firsttry);
        if q_cumtry <= MAXWAIT
            fprintf('Wait limit: %s <= %s \n',num2str(q_cumtry),num2str(MAXWAIT));
            disp('Will wait a few seconds and try again');
            pause(SINGLEWAIT);
        else
            displayerrorstruct;
            disp('Gave up trying to load');
            break;
        end
    end

end

for j = reshape(find(result_iserr),1,[])
    % GOKBERK
    multicore_warn(' ----- ERR AT SLAVE ----- ');
    fprintf('Error from resultFileName=%s\n',resultFileName);
    disp(result{j}.getReport());
end
if ~isempty(result) && any(result_iserr)
    j = find(result_iserr);


    if settings.keyboard % true
        % this is useful in case of temporary issues like out-of-memory, etc.
        retry = [];
        multicore_warn('---SLVERR-- An error reported by a slave. [keyboard] do "retry=true;dbcont;" to run at master (if master is a worker) or regeenrate the parameter file (if master is not a worker). do "retry=false;dbcont;" to quit.'); 
        keyboard;
        while(~isequal(retry,false) && ~isequal(retry,true))
            multicore_warn('set retry to either true or false');
            keyboard;
        end
    else
        retry = false;
    end

    if retry
        % if exists, delete the working file (shouldn't exist, anyway)
        % parameter file will be re-generated automatically.
        result = [];
        resultLoaded = false;
        try
            mbdelete(resultFileName,true);
            if exist(workingFileName,'file')
                multicore_warn('Weird! Working file exists??');
                mbdelete(workingFileName,true);
            end
        catch e
            disp(e.getReport());
        end
        return;
    else
        error(sprintf('--SLVERR--:\n %s \n ----------',result{j(1)}.getReport()));
    end
end

% display warning (if any)
if showWarnings
    lastMsg = lastwarn;
    if ~isempty(lastMsg)
        disp(sprintf('Warning issued when trying to load file %s:\n%s', ...
            resultFileName, lastMsg));
    end
end

% check if variable 'result' is existing
if resultLoaded && ~exist('result', 'var')
    if showWarnings
        disp(sprintf('Warning: Variable ''%s'' not existing after loading file %s.', ...
            'result', resultFileName));
    end
    resultLoaded = false;
end

if resultLoaded
    % it seems that loading was successful
    % try to remove result file
    mbdelete(resultFileName, showWarnings); %% file access %%
    if existfile(workingFileName)
        multicore_warn('this is a little weird -- result loaded but parameter/working file exists');
        % probably while a worker is running its working file is deleted.
        % so a new worker has captured the job.
    end
end

end % function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function timeString = formatTime(time, mode)
%FORMATTIME  Return formatted time string.
%		STR = FORMATTIME(TIME) returns a formatted time string for the given
%		time difference TIME in seconds, i.e. '1 hour and 5 minutes' for TIME =
%		3900.
%
%		FORMATTIME(TIME, MODE) uses the specified display mode ('long' or
%		'short'). Default is long display.
%
%		Example:
%		str = formatTime(142, 'long');
%
%		FORMATTIME (without input arguments) shows further examples.
%
%		Markus Buehren
%		Last modified 21.04.2008
%
%		See also ETIME.

if nargin == 0
    disp(sprintf('\nExamples for strings returned by function %s.m:', mfilename));
    time = [0 1e-4 0.1 1 1.1 2 60 61 62 120 121 122 3600 3660 3720 7200 7260 7320 ...
        3600*24 3600*25 3600*26 3600*48 3600*49 3600*50];
    for k=1:length(time)
        disp(sprintf('time = %6g, timeString = ''%s''', time(k), formatTime(time(k))));
    end
    if nargout > 0
        timeString = '';
    end
    return
end

if ~exist('mode', 'var')
    mode = 'long';
end

if time < 0
    disp('Warning: Time must be greater or equal zero.');
    timeString = '';
elseif time >= 3600*24
    days = floor(time / (3600*24));
    if days > 1
        dayString = 'days';
    else
        dayString = 'day';
    end
    hours = floor(mod(time, 3600*24) / 3600);
    if hours == 0
        timeString = sprintf('%d %s', days, dayString);
    else
        if hours > 1
            hourString = 'hours';
        else
            hourString = 'hour';
        end
        timeString = sprintf('%d %s and %d %s', days, dayString, hours, hourString);
    end

elseif time >= 3600
    hours = floor(mod(time, 3600*24) / 3600);
    if hours > 1
        hourString = 'hours';
    else
        hourString = 'hour';
    end
    minutes = floor(mod(time, 3600) / 60);
    if minutes == 0
        timeString = sprintf('%d %s', hours, hourString);
    else
        if minutes > 1
            minuteString = 'minutes';
        else
            minuteString = 'minute';
        end
        timeString = sprintf('%d %s and %d %s', hours, hourString, minutes, minuteString);
    end

elseif time >= 60
    minutes = floor(time / 60);
    if minutes > 1
        minuteString = 'minutes';
    else
        minuteString = 'minute';
    end
    seconds = floor(mod(time, 60));
    if seconds == 0
        timeString = sprintf('%d %s', minutes, minuteString);
    else
        if seconds > 1
            secondString = 'seconds';
        else
            secondString = 'second';
        end
        timeString = sprintf('%d %s and %d %s', minutes, minuteString, seconds, secondString);
    end

else
    if time > 10
        seconds = floor(time);
    else
        seconds = floor(time * 100) / 100;
    end
    if seconds > 0
        if seconds ~= 1
            timeString = sprintf('%.4g seconds', seconds);
        else
            timeString = '1 second';
        end
    else
        timeString = sprintf('%.4g seconds', time);
    end
end

switch mode
    case 'long'
        % do nothing
    case 'short'
        timeString = strrep(timeString, ' and ', ' ');
        timeString = strrep(timeString, ' days', 'd');
        timeString = strrep(timeString, ' day', 'd');
        timeString = strrep(timeString, ' hours', 'h');
        timeString = strrep(timeString, ' hour', 'h');
        timeString = strrep(timeString, ' minutes', 'm');
        timeString = strrep(timeString, ' minute', 'm');
        timeString = strrep(timeString, ' seconds', 's');
        timeString = strrep(timeString, ' second', 's');
    otherwise
        error('Mode ''%s'' unknown in function %s.', mode, mfilename);
end

end % function





function resultCell = irunmaster(functionHandleCell,parameterCell,resultCell,k,settings)
% Evaluate a work at master.

while(true)

    try

        if nargout > 0
            if iscell(parameterCell{k})
                resultCell{k} = feval(functionHandleCell{k}, parameterCell{k}{:});
            else
                resultCell{k} = feval(functionHandleCell{k}, parameterCell{k});
            end
        else
            assert(isempty(resultCell));
            if iscell(parameterCell{k})
                feval(functionHandleCell{k}, parameterCell{k}{:});
            else
                feval(functionHandleCell{k}, parameterCell{k});
            end
        end

        break;
    catch e

        disp(e.getReport());

        if settings.keyboard
            retry = [];
            multicore_warn(['---SLVERR (by master job=' num2str(k) ')-- keyboard. do "retry=true;dbcont;" to try running again. do "retry=false;dbcont;" to quit. see source code for more.']); 
            keyboard
            while(~isequal(retry,false) && ~isequal(retry,true))
                multicore_warn('set retry to either true or false');
                keyboard
            end
        else
            retry = false;
        end

        %{
        % if master is unable to run this (due to memory etc issues), we can assign it to a slave like this:
        % if this fails, no problem, as we're already in keyboard.

        x=startmulticoremaster(functionHandleCell{k},parameterCell(k),struct2('masterIsWorker',false)); 

        functionHandleCell{k}=@() x; parameterCell{k}={}; retry=true; dbcont;


        %}

        if ~retry
            error(sprintf('--SLVERR (by master)--:\n %s \n ----------',e.getReport()));
        end
    end

end

end










function cleanup_files(multicoreDir,dateStr)

disp(sprintf('cleaning up all job files... (*%s*)',dateStr));

% will delete all related files, but better to start from parameter files
x = dir( fullfile(multicoreDir, sprintf('parameters_%s_*.mat', dateStr)) );
for i = 1:length(x)
    fprintf('deleting %s\n',x(i).name);
    mbdelete(fullfile(multicoreDir,x(i).name), true, false);
end

x = dir( fullfile(multicoreDir, sprintf('*_%s_*', dateStr)) );
for i = 1:length(x)
    fprintf('deleting %s\n',x(i).name);
    mbdelete(fullfile(multicoreDir,x(i).name), true, false);
end

% test: cf;startmulticoremaster(@(x) x*x,repmat({{rand(500)}},1,50),struct2('masterIsWorker',false));
 

end


