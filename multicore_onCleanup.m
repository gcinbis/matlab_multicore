classdef multicore_onCleanup < handle
% Just like onCleanup, but allows changing "object.task" property.
% Set object.task=[] to cancel onCleanup action.
%
% This is a handle object, which calls "object.task" on the clean-up of the last reference. 
%
% Gokberk Cinbis

    properties(SetAccess='public', GetAccess='public', Transient)
        task;
        userdata; % to keep debug info.
    end
    
    methods

        function h = multicore_onCleanup(functionHandle)
            % Constructor multicore_onCleanup(task) where task is either [] or
            % a function handle.
            h.task = functionHandle;
            h.userdata = [];
        end
        
        function delete(h)
            try
                if ~isempty(h.task)
                    h.task();
                end
            catch e
                multicore_warn('---- UNALLOWED EXCEPTION CATCHED AT multicore_onCleanup.delete() ----');
                multicore_warn(e.getReport());
                multicore_warn('------------------------------------------------------------------');
            end
        end

    end

end

