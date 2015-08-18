function d = multicoredirs(name,newdir)
% Sets default directories for the temporary multicore parameter files.  Each directory
% is associated with a keyword "name". Directory for the same "name" can be overriden
% later.
%
% The first directory is used by default.
%
% EXAMPLE
% % Add the following command to startup.m:
% multicoredirs('global',fullfile(getenv('HOME'),'multicore'));
% % Call the following only on local slave instances:
% multicoredirs('local','/dev/shm/username/multicore/');
% % Then on the master matlab instance:
% startmulticoremaster(fh,prm); % uses the default directory
% startmulticoremaster(fh,prms,struct2('multicoreDir','local'));
%
% R.G.Cinbis July 2011

persistent names dirs
mlock

if nargin == 2 
    newdir = cn_fixpath(newdir);
    if newdir(end)~='/'
        newdir(end+1)='/'; 
    end

    fprintf('Adding multicore directory %s: %s \n',name,newdir);
    i = find( strcmp(name,names) );
    if isempty(i)
        i = length(names) + 1;
    end
    names{i} = name;
    dirs{i}  = newdir;

    if ~exist(newdir,'dir') % create directory automatically
        multicore_warn(sprintf('Creating multicore directory %s:%s\n',name,newdir));
        mkdir(newdir);
    end
elseif nargin == 1 
    if isempty(dirs)
        error('multicoredirs is not initialized yet');
    end
    i = find(strcmp(names,name),1);
    if isempty(i)
        multicore_warn(sprintf('Cant find mc name %s, using the default one.',name));
        d = dirs{1};
    else
        d = dirs{i};
    end
else
    % return all directories in order. the very first one should be considered as the default.
    if isempty(dirs)
        error('multicoredirs is not initialized yet');
    end
    d = dirs;
end



