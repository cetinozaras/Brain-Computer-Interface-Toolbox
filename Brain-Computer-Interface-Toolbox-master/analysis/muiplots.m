function muiplots(mui,chidx,freqidx)
%muiplots(mui,chidx,freqidx)
% Used to plot several channel/frequency related characteristics for 
% feature-MUI values calculated by ftr_mui.m.
%
% Example usage:
%  muiplots(MU,ft.freqidx,ft.chidx);
%
%Y.Mishchenko (c) 2016

nft=length(chidx);
nfrq=find(chidx==chidx(1),1,'last');
nch=length(unique(chidx));

freq=freqidx(1:nfrq);

ft=mui(end-4*nft+1:end-2*nft);
ft=reshape(ft,nfrq,[]);
ftc=ft(:,1:nch)+ft(:,nch+1:end);

%real-imaginary cummulative mui per freq/channel
figure,imagesc(ftc),colormap gray,colorbar
title('Real-imaginary cummulative MUI per freq/channel');
xlabel('Channels'),ylabel('Frequency labels');

%naive total information content per channel, all frequencies
figure,plot(sum(ftc,1),'d-')
title('Total naive information per channel (all frequencies)');
xlabel('Channels'),ylabel('Total information, nats');

%naive total information content per channel, <=5Hz
thr=5;
figure,plot(sum(ftc(freq<=thr,:),1),'d-')
title(sprintf(...
 'Total naive information per channel (<=%g Hz)',thr));
xlabel('Channels'),ylabel('Total information, nats');

%naive total information content per frequency, all channels
figure,plot(freq,sum(ftc,2),'d-')
title('Total naive information per frequency (all channels)');
xlabel('Frequencies'),ylabel('Total information, nats');

end
