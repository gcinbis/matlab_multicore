function gokberk_save_slave(resultFileName,result,result_iserr)

if numel(result) ~= numel(result_iserr)
    error('result_iserr seems wrong!');
end

% -v7 is smaller but slower!
%multicore_savev6(resultFileName, 'result','result_iserr'); %% file access %% advantage over save(): if save fails, it deletes the file
multicore_savev6(resultFileName, '-force', 'result','result_iserr'); %% file access %% avoid infinite loop when the result file already exists

