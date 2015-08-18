function c = vec2cell(x)
% To quickly convert a vector into a cell array.
%
% NOTE THIS FUNCTION IS OBSOLETE. USE NUM2CELL OF MATLAB INSTEAD.
%
% INPUT
% x     A single-dim numeric/logical/structure array.
% 
% OUTPUT 
% c     A cell array of size=size(x) where c{i}=x(i)
%
% R.G.Cinbis May 2011

cn_assert(isvector(x));
% no need: cn_assert(isnumeric(x));

n = length(x);
c = cell(size(x));
for i = 1:n
    c{i}=x(i);
end


