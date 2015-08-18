function randinfo = cn_saverandstream()
% randinfo = cn_saverandstream()
%
% Saves the information about the current random stream against
% creation of new streams / change of current stream's state.
%
% Use cn_loadrandstream() to load back.
% Better use cn_rememberrandstream() to protect the random stream during function execution.
%
% EXAMPLE
% x=cn_saverandstream(); rand, rand, cn_loadrandstream(x); rand, rand
%
% R.G.Cinbis April 2010

%randinfo.stream = RandStream.getDefaultStream;
randinfo.stream = RandStream.getGlobalStream;
randinfo.state = randinfo.stream.State;

