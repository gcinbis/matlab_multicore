function res = begstr(txt,pattern)
% res = begstr(txt,pattern)
%
% Returns true only if txt starts with the pattern.
%
% SEE hasstr
%
% R.G.Cinbis March 2011

assert(ischar(pattern));
if ~iscell(txt) && ~ischar(txt) % necessary!
    error('txt is not supported');
end
res = strncmp(txt,pattern,length(pattern));

