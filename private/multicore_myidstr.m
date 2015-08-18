function idstr = multicore_myidstr(msec,hostname,pid)
% idstr = multicore_myidstr(msec,hostname,pid)
%
% Create an identification string that is very difficult to overlap
% with other processes and easy to understand visually.
%
% INPUT
% [msec]     (def=true)
% [hostname] (def=true)
% [pid]      (def=true) If fails, this is replaced by 'pid'.
%
% OUTPUT
% idstr:    String generated.
%
% R.G.Cinbis Oct 2010

cn_setvardefaults(true,'msec',1,'hostname',1,'pid',1);

if msec 
    x = datestr(now,'yyyy-mm-dd_HH-MM-SS.FFF');
else
    x = datestr(now,'yyyy-mm-dd_HH-MM-SS');
end

if hostname
    y = ['-' cn_hostname()];
else
    y = '';
end

if pid
    try
        z = ['-' num2str( multicore_processid() )];
    catch
        z = '-pid';
    end
else
    z = '';
end

idstr = [x y z];

