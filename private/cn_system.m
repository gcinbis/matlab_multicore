function [status,result] = cn_system(cmd,varargin)
% Same as system(), however, avoid stdin getting into the results under Linux.
% Do NOT call this function for interactive executables.
% 
% USAGE
% [status,result] = cn_system(cmd)
% [status,result] = cn_system(cmd,'-echo')
%
% EXAMPLE
% [a,b] = system('sleep 2') % write stuff while waiting
% [a,b] = cn_system('sleep 2') % write stuff while waiting
%
% R.G.Cinbis, Feb 2013

% todo: replace with a mex function?

if isunix && ~any(cmd(:)=='<') && ~any(cmd(:)=='>') && ~any(cmd(:)=='|') % just be at the safe side. if there is any pipelineing, then it is possibly wrong
    cmd = [cmd ' < /dev/null'];
end

if nargout==0
    system(cmd,varargin{:});
elseif nargout==1
    [status] = system(cmd,varargin{:});
elseif nargout==2
    [status,result] = system(cmd,varargin{:});
end




