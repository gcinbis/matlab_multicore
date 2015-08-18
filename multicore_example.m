function multicore_example()
% A simple example that demonstrates the use of multicore package.
%
% USAGE 
%
% Add multicoredirs() calls to startup.m before running any matlab instances.
% Example: multicoredirs('global',fullfile(getenv('HOME'),'multicore'));  
% Initialize slave processes on several matlab instances via startmulticoreslave(). Slaves on multiple machines can be used by hosting the source code on a network drive.
% Call multicore_example on the master matlab instance.
%


multicore_warn('no output');
t = 1:8
startmulticoremaster(@helper,vec2cell(t),[]);

multicore_warn('with output');
x = startmulticoremaster(@helper,vec2cell(t),[]);

t = 1:8
x = startmulticoremaster(@helper2,vec2cell(t),struct2('nrOfEvalsAtOnce',3));;
assert(isequal([x{:}],t));


function res = helper(t)

if t < 4
    pause(0.1)
else
    pause(1.5) % make master wait a bit
end

if nargout > 0
    res = rand(1);
end



function res = helper2(t)

res = t;




