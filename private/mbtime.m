function nowinseconds = mbtime
%MBTIME  Return serial date number converted to seconds
%		TIME = MBTIME returns the serial date number as returned by function
%		NOW converted to seconds.
%
%		Example:
%		time = mbtime;
%
%		Markus Buehren
%		Last modified 21.04.2008 
%
%		See also NOW, CLOCK, DATENUM.

% function datenummx is a mex-file found in toolbox/matlab/timefun
% gokberk: should be the same with datenum()
nowinseconds = datenummx(clock)*86400;
