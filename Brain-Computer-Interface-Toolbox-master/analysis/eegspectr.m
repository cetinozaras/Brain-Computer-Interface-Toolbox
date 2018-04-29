function eegspectr(o,chidx,TT,FF,TTs,fprefix)
%eegspectr(o,chidx,TT,FF,TTs,fmode,foffset,dirname)
% Produce and display spectrograms and overall spectra for an EEG
% experiment data in 'o'. Produces the spectrograms and the spectra
% for all eeg channels listed in index list 'chidx'. 'TT' specifies
% the length of the short-time FFT window, in seconds (optional,
% TT=15 sec default). Specify the list of frequencies F to calculate
% FFT for only these frequencies (optional, F=1:64 default).  Specify
% a range TTs to use t-subset of data (optional).
%
% 'fprefix' can be used in batch mode and specifies the directory to 
% which the figures will be printed.
%
% Example usage:
%  eegspectr(o,1)
%  eegspectr(o,1:21,[],[],[],'analysis-nkdeney-yuriy-20151027')
%
%Y.Mishchenko (c) 2015

%% SETTINGS
fs=o.sampFreq;  %sampling frequency in the data

if(nargin<3 || isempty(TT))
  TT=15;
end
if(nargin<4 || isempty(FF))
  FF=2*fs;
  frqmax=64;
else
  frqmax=max(FF);
end
if(nargin<5 || isempty(TTs))
  TTs=1:o.nS;
end
if(nargin<6)
  fprefix=[];
else
  close all
end


for ch=chidx
  %% EEG SPECTROGRAM
  fprintf('Calculating the spectrogram for channel %i...\n',ch);
  
  %Here:
  % S is the Fourier transform (amplitude + phase, complex value);
  % F is set of frequencies for S,P (vertical dim);
  % T is set of times for S,P (horizontal dim);
  % P is power spectra (amplitude^2)
  % TT is the length of the window on which to calculate stfft
  % half-second step
  tic
  [S,F,T,P] = spectrogram(o.data(TTs,ch),blackman(TT*128),TT*128-64,FF,fs);
  toc
  
  %remove zero-frequency==constant bias
  P=P(F>0 & F<=frqmax,:);
  F=F(F>0 & F<=frqmax);
  
  %% PLOTTING
  %Calculate bands, delta, theta, alpha, beta, gamma
  %Bands reminder:
  % alpha  8-15Hz
  % beta   16-32Hz
  % gamma  32+ Hz
  % delta  1-4Hz
  % theta  4-7Hz
  PB=[sum(P(F>0 & F<4,:),1); sum(P(F>=4 & F<8,:),1); ...
    sum(P(F>=8 & F<16,:),1);sum(P(F>=16 & F<32,:),1);sum(P(F>=32,:),1)];
  
  %Calculate total spectrum
  ST=sum(P,2);
  
  stitle=sprintf('Channel %i (%s)',ch,o.chnames{ch});
  
  %plot spectrogram
  if(~isempty(fprefix))
    figure(ch);
  else
    figure
  end
  
  set(gcf, 'Position', get(0,'Screensize')); % Maximize figure.
  surf(T/60,F,10*log10(P),'EdgeColor','none')
  axis xy; axis tight; colormap(jet); view(0,90); colorbar;
  xlabel('Time (Min)');
  ylabel('Frequency (Hz)');
  title(stitle)
  zoom reset
  zoom xon
  pan xon
  
  if(~isempty(fprefix))
    tic
    savefigs(ch,[fprefix,'\spectrogram']);
    close(ch);
    toc
  end
  
  %plot bands
  if(~isempty(fprefix))
    figure(ch);
  else
    figure
  end
  
  set(gcf, 'Position', get(0,'Screensize')); % Maximize figure.
  imagesc(T/60,[1,2,3,4,5],10*log10(PB))
  axis xy; colorbar;
  set(gca,'YTick',[1 2 3 4 5])
  set(gca,'YTickLabel',{'Delta ','Theta ','Alpha ','Beta ','Gamma '})
  xlabel('Time (Min)');
  ylabel('Frequency (Hz)');
  title(stitle);
  zoom reset
  zoom xon
  pan xon
  
  if(~isempty(fprefix))
    tic
    savefigs(ch,[fprefix,'\spectralbandpower']);
    close(ch);
    toc
  end
  
  %plot total spectrum
  if(~isempty(fprefix))
    figure(ch);
  else
    figure
  end
  
  plot(F,10*log10(ST))
  xlabel('Frequency (Hz)');
  ylabel('Power, dB');
  title(stitle);
  grid on
  
  if(~isempty(fprefix))
    tic
    savefigs(ch,[fprefix,'\spectrum']);
    close(ch);
    toc
  end
  
  pause(0.1);
end

end
