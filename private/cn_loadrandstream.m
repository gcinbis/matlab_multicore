function cn_loadrandstream(randinfo)
% cn_loadrandstream(randinfo)
% 
% Set the stream&state saved by cn_saverandstream() as the default
% random generator. Use with cn_setrandseed safely.
%
% R.G.Cinbis April 2010

gen = randinfo.stream;
gen.State = randinfo.state;
%RandStream.setDefaultStream(gen);
RandStream.setGlobalStream(gen);


