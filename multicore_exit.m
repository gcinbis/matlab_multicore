function multicore_exit
% Call 'exit' on all multicore slaves. Does NOT finish automatically since some slaves might be running, and, it is hard
% to detect. Waits for slaves to exit until Ctrl-C is used.
%
% It is typically easier to kill matlab processes "manually", though.
%
% R.G.Cinbis March 2012

params = {{}};
fun = @() 1;

settings.spec = 'exit';
settings.masterIsWorker = false;
settings.maxEvalTimeSingle = inf;
settings.keyboard = false;

mdb c
disp('Waiting for slaves to exit. Press Ctrl-C when you think youre done');

startmulticoremaster(fun,params,settings);



