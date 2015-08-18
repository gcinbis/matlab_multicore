function startmulticoreslave(multicoreDir)
%STARTMULTICORESLAVE  Start multi-core processing slave process.
%   STARTMULTICORESLAVE(DIRNAME) starts a slave process for function
%   STARTMULTICOREMASTER. The given directory DIRNAME is checked for data
%   files including which function to run and which parameters to use.
%
%   STARTMULTICORESLAVE (without input arguments) uses the directory
%   <TEMPDIR>/multicorefiles, where <TEMPDIR> is the directory returned by
%   function tempdir.
%
%   GOKBERK For local-only slaves, use multicoreDir='local', given the suggested settings
%   in multicoredirs()
%
%		Markus Buehren
%		Last modified 10.04.2009
%               Modified by Gokberk Cinbis.
%
%   See also STARTMULTICOREMASTER.
% 

%{
function aa
% to play with ctrl-c, etc.

startmulticoremaster(@bb,{{},{}})

function out = bb

out = rand
keyboard
%}

debugMode    = 0;
showWarnings = 1;

% GOKBERK. Ctrl-C should be made easy. Due to try-catch, "dbstop if error" is
% not useful anyway.
disp('dbclear if error');
dbclear if error

if debugMode
    % activate all messages
    showWarnings = 1;
end

% GOKBERK
gokberk_orgdir = pwd();

% parameters
firstWarnTime = 10;
startWarnTime = firstWarnTime; % GOKBERK 10*60;
maxWarnTime   = 24*3600;
startWaitTime = 0.5;
maxWaitTime   = 5;

if debugMode
    firstWarnTime = 10;
    startWarnTime = 10;
    maxWarnTime   = 60;
    maxWaitTime   = 1;
end

persistent lastSessionDateStr

% this will be used to delete "working" file to indicate that the function didn't terminate
% properly. master should re-create the parameter file. alternative: re-create the parameter file on
% failure.
cleanupobj = multicore_onCleanup([]);

% get slave file directory name
if ~exist('multicoreDir', 'var') || isempty(multicoreDir)
    all_multicoreDir = multicoredirs();
else
    % work on a single directory.
    all_multicoreDir = cellifnot(multicoredirs(multicoreDir));
end
clear multicoreDir;

% initialize variables
lastEvalEndClock = clock;
lastWarnClock    = clock;
firstRun         = true;
curWarnTime      = firstWarnTime;
curWaitTime      = startWaitTime;

disp('slave started'); % GOKBERK

dirindex = 0;
while 1
    cd(gokberk_orgdir);
    
    % check the next directory.
    dirindex = dirindex + 1;
    if dirindex > length(all_multicoreDir)
        dirindex = 1;
    end

    multicoreDir = all_multicoreDir{dirindex};
    parameterFileList = findfiles(multicoreDir, 'parameters_*.mat', 'nonrecursive');

    % GOKBERK: ignore parameter files on which we're working.
    parameterFileList = setdiff(parameterFileList, ...
        strrep(findfiles(multicoreDir, 'working_*.mat','nonrecursive'),'working_','parameters_'));
    
    % get last file that is not a semaphore file
    % GOKBERK UPDATE: We want to start from the older job. 
    parameterFileName = '';
    workingFile = '';
    parameterFileList = parameterFileList(~hasstr(parameterFileList,'semaphore'));
    parameterFileList = parameterFileList(getjobids(parameterFileList)==1);
    if ~isempty(parameterFileList)
        parameterFileName = parameterFileList{end}; % now select the last chunk within the oldest job
    end
    if ~isempty(parameterFileName)

    
        if debugMode
            % get parameter file number for debug messages
            fileNr = str2double(regexptokens(parameterFileName,'parameters_\d+_(\d+)\.mat'));
            disp(sprintf('****** Slave is checking file nr %d *******', fileNr));
        end
        
        % load and delete last parameter file
        sem = setfilesemaphore(parameterFileName);
        loadSuccessful = true;
        workingFile = strrep(parameterFileName, 'parameters', 'working');
        if existfile(parameterFileName) && ~existfile(workingFile) % check AFTER semaphore 
            % try to load the parameters
            lastwarn('');
            lasterror('reset');
            try
                % GOKBERK: First go to the directory and then load the
                % function handles, in order to let matlab find the 'inner'
                % functions.
                load(parameterFileName, 'gokberk_curdir'); %% file access %%
                cd(gokberk_curdir);
                load(parameterFileName, 'functionHandles', 'parameters','internal'); %% file access %%
                assert(~existfile(workingFile)); % just to make sure
            catch
                loadSuccessful = false;
                if showWarnings
                    disp(sprintf('Warning: Unable to load parameter file %s.', parameterFileName));
                    lastMsg = lastwarn;
                    if ~isempty(lastMsg)
                        disp(sprintf('Warning message issued when trying to load:\n%s', lastMsg));
                    end
                    displayerrorstruct;
                end
            end
            
            % check if variables to load are existing
            if loadSuccessful && (~exist('functionHandles', 'var') || ~exist('parameters', 'var') || ~exist('internal', 'var')) 
                loadSuccessful = false;
                if showWarnings
                    disp(textwrap2(sprintf(['Warning: Either variable ''%s'' or ''%s''', ...
                        'or ''%s'' not existing after loading file %s.'], ...
                        'functionHandles', 'parameters', parameterFileName)));
                end
            end
            
            if debugMode
                if loadSuccessful
                    disp(sprintf('Successfully loaded parameter file nr %d.', fileNr));
                else
                    disp(sprintf('Problems loading parameter file nr %d.', fileNr));
                end
            end
            
            % old:remove parameter file
            % GOKBERK: Dont delete. Keep it, working file will indicate that it is under evaluation.
            % If we ever delete the working file, some other worker can grab the working file
            % easily.
            %deleteSuccessful = mbdelete(parameterFileName, showWarnings); %% file access %%
            %if ~deleteSuccessful
            %    % If deletion is not successful it can happen that other slaves or
            %    % the master also use these parameters. To avoid this, ignore the
            %    % loaded parameters
            %    loadSuccessful = false;
            %    if debugMode
            %        disp(sprintf('Problems deleting parameter file nr %d. It will be ignored', fileNr));
            %    end
            %end
        else
            loadSuccessful = false;
            if debugMode
                disp('No parameter files found.');
            end
        end
        
        % remove semaphore and continue if loading was not successful
        if ~loadSuccessful
            removefilesemaphore(sem);
            continue
        end

        if isequal(internal.spec,'exit')
            % Simply quit without generating working file.
            % Any worker should read parameters and exit.
            % Param file will be deleted by the master.
            disp('spec=exit, exiting');
            exit
        end
        
        % Generate a temporary file which shows when the slave started working.
        % Using this file, the master can decide if the job timed out.
        % Still using the semaphore of the parameter file above.
        workingFile = strrep(parameterFileName, 'parameters', 'working');
        generateemptyfile(workingFile);
        if debugMode
            disp(sprintf('Working file nr %d generated.', fileNr));
        end
        
        % remove semaphore file for the parameters file
        removefilesemaphore(sem);
        
        % show progress info
        if firstRun
            disp(sprintf('First function evaluation (%s)', datestr(clock, 'mmm dd, HH:MM')));
            firstRun = false;
        elseif etime(clock, lastEvalEndClock) > 60
            disp(sprintf('First function evaluation after %s (%s)', ...
                formattime(etime(clock, lastEvalEndClock)), datestr(clock, 'mmm dd, HH:MM')));
        end
        
        %%%%%%%%%%%%%%%%%%%%%
        % evaluate function %
        %%%%%%%%%%%%%%%%%%%%%
        if debugMode
            disp(sprintf('Slave evaluates job nr %d.', fileNr));
            t0 = mbtime;
        end
        
        % Check if date string in parameter file name has changed. If yes, call
        % "clear functions" to ensure that the latest file versions are used,
        % no older versions in Matlab's memory.
        sessionDateStr = regexptokens(parameterFileName, 'parameters_(\d+)_\d+\.mat');
        if ~strcmp(sessionDateStr, lastSessionDateStr)
            clear functions
            
            % GOKBERK: Just to be sure.
            fprintf('clear functions, close all, now will work on file: %s\n',parameterFileName);

            % GOKBERK: close open figures
            close all
        end
        lastSessionDateStr = sessionDateStr;

        % to handle ctrl-c occurring before we save the output
        cleanupobj.task = @() cleanup_workingfile(workingFile);
        
        result = cell(size(parameters)); %#ok
        result_iserr = false(size(parameters));
        for k=1:numel(parameters)
            try
                if internal.nargout > 0
                    if iscell(parameters{k})
                        result{k} = feval(functionHandles{k}, parameters{k}{:}); %#ok
                    else
                        result{k} = feval(functionHandles{k}, parameters{k}); %#ok
                    end
                else
                    if iscell(parameters{k})
                        feval(functionHandles{k}, parameters{k}{:}); %#ok
                    else
                        feval(functionHandles{k}, parameters{k}); %#ok
                    end
                end
            catch gokberk_err
                multicore_warn('ERROR IN EXECUTION -- RESULT IS THE MException OBJECT');
                multicore_warn(gokberk_err.getReport());
                result{k} = gokberk_err;
                result_iserr(k) = true;
                break; % Sep'11
            end
        end
        if debugMode
            disp(sprintf('Slave finished job nr %d in %.2f seconds.', fileNr, mbtime - t0));
        end       
        
        % Save result. Use file semaphore of the parameter file to reduce the
        % overhead.
        sem = setfilesemaphore(parameterFileName);
        resultFileName = strrep(parameterFileName, 'parameters', 'result');
        try
            gokberk_save_slave(resultFileName,result,result_iserr);
            if debugMode
                disp(sprintf('Result file nr %d generated.', fileNr));
            end
        catch e
            if showWarnings
                disp(sprintf('Warning: Unable to save file %s.', resultFileName));
                disp(e.getReport());
            end
        end
      
        % remove parameter file 
        mbdelete(parameterFileName, showWarnings); %% file access %%
        if debugMode
            disp(sprintf('Parameter file nr %d deleted.', fileNr));
        end

        % remove working file
        mbdelete(workingFile, showWarnings); %% file access %%
        if debugMode
            disp(sprintf('Working file nr %d deleted.', fileNr));
        end
        
        % task is completed. no need to panic anymore.
        % note that if there is an error thats catched, it will be reported to the master.
        % but if user "dbquit"s during a keyboard the experiment
        cleanupobj.task = [];

        % remove semaphore
        removefilesemaphore(sem);
        
        % save time
        lastEvalEndClock = clock;
        curWarnTime = startWarnTime;
        curWaitTime = startWaitTime;
        
        % remove variables before next run
        clear result functionHandle parameters internal
        
    else
        % display message if idle for long time
        timeSinceLastEvaluation = etime(clock, lastEvalEndClock);
        if min(timeSinceLastEvaluation, etime(clock, lastWarnClock)) > curWarnTime
            if timeSinceLastEvaluation >= 10*60
                % round to minutes
                timeSinceLastEvaluation = 60 * round(timeSinceLastEvaluation / 60);
            end
            disp(sprintf('Warning: No slave files found during last %s (%s).', ...
                formattime(timeSinceLastEvaluation), datestr(clock, 'mmm dd, HH:MM')));
            lastWarnClock = clock;
            if firstRun
                curWarnTime = startWarnTime;
            else
                curWarnTime = min(curWarnTime * 2, maxWarnTime);
            end
            curWaitTime = min(curWaitTime + 0.5, maxWaitTime);
        end
        
        if dirindex==1
            % wait before next check
            pause(curWaitTime);
        end
        
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function timeString = formattime(time, mode)
%FORMATTIME  Return formatted time string.
%   STR = FORMATTIME(TIME) returns a formatted time string for the given
%   time difference TIME in seconds, i.e. '1 hour and 5 minutes' for TIME =
%   3900.
%
%   FORMATTIME(TIME, MODE) uses the specified display mode ('long' or
%   'short'). Default is long display.
%
%   FORMATTIME (without input arguments) shows examples.

if nargin == 0
    disp(sprintf('\nExamples for strings returned by function %s.m:', mfilename));
    time = [0 1e-4 0.1 1 1.1 2 60 61 62 120 121 122 3600 3660 3720 7200 7260 7320 ...
        3600*24 3600*25 3600*26 3600*48 3600*49 3600*50];
    for k=1:length(time)
        disp(sprintf('time = %6g, timeString = ''%s''', time(k), formattime(time(k))));
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


function cleanup_workingfile(workingFile)
% this allows us to quit (ctrl-c not kill!) workers without disrupting the whole process.
% it will just delete the worker file but not the corresponding parameter file.
% therefore, job will be ready to use again.

% todo: semaphore needed?
mbdelete(workingFile, true); %% file access %%
multicore_warn(sprintf('Ctrl-C --> Working file %s deleted.', workingFile));
multicore_warn('Unless the parameter file is deleted, another worker should restart the job.');



function jobids = getjobids(parameterFileList)

jobnames = cell(size(parameterFileList));
invalidjob = false(size(parameterFileList));
for j = 1:length(parameterFileList)
    n = parameterFileList{j};
    k = find(n=='_',1,'last');
    if isempty(k)
        disp(['unrecognized job name: ' n]);
        invalidjob(j) = true; continue;
    end
    jobnames{j} = n(1:(k-1));
end

[~,~,jobids] = unique(jobnames);
jobids(invalidjob) = -1;




