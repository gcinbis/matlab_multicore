function res = hasstr(txt,pattern)
% res = hasstr(txt,pattern)
%
% Returns true only if txt has the string pattern.
% txt can be a cell array of strings.
%
% SEE begstr
%
% R.G.Cinbis March 2011

assert(ischar(pattern));
if iscell(txt)
    res = false(size(txt));
    for j = numel(txt):-1:1
        res(j) = ~isempty(strfind(txt{j},pattern));
    end
else
    assert(ischar(txt));
    res = ~isempty(strfind(txt,pattern));
end

