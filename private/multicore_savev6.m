function multicore_savev6(filename,varargin)
% multicore_savev6(filename,varargin)
%
% Saves in v6 as long as all variables have size < 2GB.  Otherwise, saves in v7.3 format. 
% If a "-v*" argument is provided, does not override user's argument.
%
% Supports any directive of save() function like -append, -struct, etc. This is only a wrapper.
%
% In practice, this function can be a good substitute for any call to save(). v7.3 supports very
% large files but it can be much slower to read/write. It can also have a size overhead in small
% files. For v7, one can always pass '-v7' or '-v7.3' to override multicore_savev6 defaults.
%
% v7.3 can have a big overhead in small files but it can greatly compress large files.
%
% In contrast to save(),
%   - This function will deny overwrite onto the file, unless '-force' switch
%   is passed.
%   - If save() throws an exception, it will first delete the possibly
%   corrupted output file. If -force is passed, this may cause original file
%   to be deleted where save() failed due to write permissions.
%   - If there is unsufficient space, usually -v6 throws exception (and multicore_savev6 deletes the corrupted file)
%   however -v7 sometimes does not throw any exception or warnings, therefore, multicore_savev6 cannot cleanup.
%   At the end, trying to read such a -v7 file says "unexpected end-of-file while reading compressed data".
%   - First saves into a temp file under the same directory and then moves the file.
%   This is useful whne multicore_savev6 is used sth. like multicore toolbox.
% 
% INPUT
% filename
% varargin      Arguments as defined in save() function.
%
% SEE save
% 
% R.G.Cinbis, August 2011

% like save
if nargin<1
    filename=fullfile(fileparts(mfilename('full')),'matlab.mat');
    fprintf('multicore_savev6:: Saving to %s\n',filename);
end

assert(ischar(filename)); % better do it here.

% like save(filename) or save 'filename'
if nargin<2
    % get variable names
    args = evalin('caller','who();');
    fprintf('multicore_savev6:: Saving variables: ');
    fprintf('%s ',args{:});
    fprintf('\n');
else
    args = detach(varargin);
end

[args,force] = checkforce(args);
if ~force && multicore_isfileordir(filename)
    error(['File already exists: ' filename]);
end

% find temp name
filename_tmp = gettmpname(filename);

% choose the version.
if ~any(begstr(args,'-v'))

    % check if any of the variables is too large to save with v6.
    largenames = {};
    i = 1;
    while(i<=length(args))
        n = args{i};
        assert(ischar(n)); % better do it here.
        if strcmpi('-struct',strtrim(n))
            n = args{i+1};
            x = evalin('caller',[n ';']); % get struct
            assert(isstructscalar(x),'-struct must be followed by a scalar struct'); % matlab doesnt accept even [].
            x_flds = fieldnames(x);
            for x_fi = 1:length(x_flds) % go over its fields
                x_c = x.(x_flds{x_fi});
                s = whos('x_c');
                if (s.bytes + 1) >= 2e9
                    largenames{end+1} = [n '.' x_flds{x_fi}];
                end
            end
            i=i+2;
        elseif ~isvarname(n)
            i = i + 1;
        else
            x = ['whos(''' n ''');'];
            s = evalin('caller',x);
            if isempty(s)
                fprintf('multicore_savev6:: Cant find the variable %s\n',n);
            elseif (s.bytes + 1) >= 2e9
                largenames{end+1} = n;
            end
            i = i + 1;
        end
    end

    if isempty(largenames)
        v = '-v6';
    else
        v = '-v7.3';
        fprintf('multicore_savev6:: Using -v7.3 due to the size of the following variables: ');
        fprintf('%s ',largenames{:});
        fprintf('\n');
    end
    x = sprintf('''%s'',',filename_tmp,v,args{:}); % call save().
else
    x = sprintf('''%s'',',filename_tmp,args{:}); % call save().
end
x(end) = ')'; % replace "," with ")".
x = ['save(' x ';'];

deleter = multicore_onCleanup(@() docleanup(filename,filename_tmp)); % this is safer than try-catch in case of ctrl-c.
%disp(x)
evalin('caller',x);
assert(movefile(filename_tmp,filename));
deleter.task = []; 




function docleanup(filename,filename_tmp)

if multicore_isfileordir(filename_tmp)=='f'
    multicore_warn(['multicore_savev6: Deleting possibly corrupted file: ' filename_tmp]);
    cn_delete(filename_tmp,false);
else
    multicore_warn(['multicore_savev6: File does not seem to exist, no need to delete: ' filename_tmp]);
end


if multicore_isfileordir(filename)=='f'
    multicore_warn(['multicore_savev6: Deleting possibly corrupted file: ' filename]);
    cn_delete(filename,false);
end

function [args,force] = checkforce(args)
% check if -force is passed.
% return args without -force switch.

m = false(1,length(args));
for i = 1:length(args)
    if isequal(args{i},'-force')
        m(i) = true;
    end
end

args = args(~m);
force = any(m);



function filename_tmp = gettmpname(filename)


main = [filename '.' cn_hostname() '.' num2str(multicore_processid())];

% 2015-01-25
% avoid problematic characters in evalin() (this is temporary anyways)
main = strrep(main,'''','_');

filename_tmp = main;
j = 1;
while(multicore_isfileordir(filename_tmp))
    j = j + 1;
    filename_tmp = [main '.' num2str(j)];
end





