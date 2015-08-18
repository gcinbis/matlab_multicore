function copyHelperFunctions(utils_root)
% Copy helper functions from "myutils" to here.
% Gokberk Cinbis, 2014

list = {
'system/cn_setvardefaults.m'
'system/cn_setfielddefaults.m'
'system/cn_timepassth.m'
'system/cn_fixpath.m'
'system/cn_hostname.m'
'shortcuts/vec2cell.m'
'miscutils/cn_assert.m'
'system/cn_genvarname.m'
'system/cn_system.m'
'system/cn_saverandstream.m'
'system/cn_loadrandstream.m'
'system/detach.m'
'shortcuts/begstr.m'
'shortcuts/hasstr.m'
'shortcuts/struct2.m'
};

% other functions that are obtained by modifying myutils functions:
% - multicore_isfileordir
% - multicore_savev6
% - multicore_warn
% - multicore_myidstr
% - multicore_onCleanup

r = fileparts(mfilename('fullpath'));
for j = 1:numel(list)
    copyfile(fullfile(utils_root,list{j}),r);
end


