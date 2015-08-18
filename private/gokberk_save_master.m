function gokberk_save_master(parameterFileName,functionHandles,parameters,internal)

% GOKBERK
gokberk_curdir = pwd();

% -v7 is smaller but slower!
multicore_savev6(parameterFileName, 'functionHandles', 'parameters','internal','gokberk_curdir'); %% file access %%

