function res = multicore_isfileordir(path)
% Check if a file or directory exists. Note that multicore_isfileordir(path)>0 is equivalent to "exists".
%
% INPUT
% path      Just a path. Is not allowed to have wildcards.
%           To use with cell array, use cellfun(@multicore_isfileordir,paths). Cell
%           arrays are not supported to avoid mistakes.
%
% OUTPUT
% res       'f'     A file or a symlink to a file.
%           'd'     A directory or a symlink to a directory. Whether to give '/' at the end 
%                   doesnt matter. Behaviour is consistent with isdir() of matlab.
%           char(0) File/directory doesn't exist (or symlink is broken). Note that double(0)==char(0)==false
%
% R.G.Cinbis, Oct 2011

try
    res = isfileordir(path); % use if available
catch
    res = helper(path);
end


function res = helper(path)

if iscell(path)
    error('Cell array of paths is not supported to avoid mistakes');
end

if isempty(path)
    path = pwd;
end

assert(~any(path=='*'),'wildcards in the path are not allowed!');

% before calling dir(path), check if it is a directory.
if isdir(path)
    res = 'd';
else
    x = dir(path); % dont use exist() here, I find it less reliable.

    if isempty(x)
        res = char(0);
    elseif length(x) > 1
        error('bug!');
    else
        assert(~(x.isdir)); % sanity check
        res = 'f';
    end

end

