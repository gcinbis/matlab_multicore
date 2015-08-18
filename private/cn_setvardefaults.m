function cn_setvardefaults(overwriteifempty,varargin)
% cn_setvardefaults(overwriteifempty,varname1,defval1,varname2,defval2,...)
% 
% Sets default values to variable that does not currently exist in the
% caller workspace.
% 
% overwriteifempty: If true, variables that exist but set to empty
%                   will be set to their default values.
% 
% R. Gokberk Cinbis, January 2009

% $Id: cn_setvardefaults.m,b 1.2 2010/02/23 01:47:46 gcinbis Exp $ 

% dont use it here, avoid function call overhead: cn_assert
if mod(length(varargin),2)~=0
    error('varargin should have even number of entries');
end

for j = 1:2:length(varargin)
    vname = varargin{j};
    vx = varargin{j+1};

    a1 = [ 'exist( '''   vname   ''', ''var'' )' ];
    if ~evalin('caller',a1) || ...
        (overwriteifempty && evalin('caller',['isempty(' vname ')']))
        assignin('caller',vname,vx);
    end
end

