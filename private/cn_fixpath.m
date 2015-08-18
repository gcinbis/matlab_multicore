function path = cn_fixpath(path)
% Standardize the path such that there is no '\' in it. Only '/' is used as a path separator.
%
% SEE cn_followlink

path = fullfile(path);
if ispc
    path = strrep(path,'\','/'); % for cygwin compability
end


