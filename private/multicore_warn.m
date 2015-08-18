function multicore_warn(varargin)
% multicore_warn(line1,line2,...)

try
    mywarn(varargin{:}); % if a custom mywarn() function is available..
catch
    % blue is good both for dark and light backgrounds.
    fprintf('**** WARNING ****\n');
    fprintf('%s\n',varargin{:});
end

