function name = cn_hostname()
% Returns hostname (without domain name) 
% Efficient, calculates only in the first call.
%
% ** Hack: Removes .inrialpes.fr
% 
% R.G.Cinbis Jan 2010

persistent compinfo

if isempty(compinfo)
    %compinfo = whoami;
    % name = compinfo.host
    if isunix
        [foo,name] = cn_system('hostname -s'); 
    else
        %[foo,name] = cn_system('hostname'); % cygwin doesnt support -s
        name=getenv('COMPUTERNAME');
    end
end
%name = strtrim(name);
%name = name(name~=sprint('\n'));
name = strrep(name,'.inrialpes.fr',''); % HACK
name = cn_genvarname(name);

%     % doesnot work with parallel processing!
%     [ret, name] = system('hostname');
%     
%     if ret ~= 0,
%         if ispc
%             name = getenv('COMPUTERNAME');
%         else
%             name = getenv('HOSTNAME');
%         end
%     end
%     name = strtrim(lower(name));

