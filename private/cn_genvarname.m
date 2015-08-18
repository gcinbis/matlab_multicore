function x = cn_genvarname(x)
% x = cn_genvarname(x)
%
% Like genvarname() but for almost all invalid characters,
% replaces with _ instead of hard-to-read choices of genvarname().
%
% SEE cn_genvarname cn_genfilename
%
% R.G.Cinbis March 2010


x = strtrim(x);

x( ~(x>='0' & x<='9') & ~(x>='a' & x<='z') & ~(x>='A' & x<='Z') ) = '_';

x = genvarname(x);


