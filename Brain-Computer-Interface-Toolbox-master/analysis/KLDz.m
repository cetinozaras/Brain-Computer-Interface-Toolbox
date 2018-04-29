function kl=KLDz(X,Z,M)
%mui=MUIz(X,Z,M)
%Simple (1D) KL-divergence using histograms.
% X should be 1 x n array of n observations of the realizations of a 
% 1-dimensional continuous-valued random variable X, Z should be a 
% 1 x n array of the observations of a 1-dimensional two-valued ({0,1})
% random variable Y. The number of the observations of both X and Z 
% MUST be the same, n. M is the number of bins to use in the histograms.
%
% Y.Mishchenko (c) 2015

%This implements MUI(X,Z)=H(X)-H(X|Z) where H(X|Z)=sum_z n(z)/N*H(X|Z==z).
%For continuous entropy estimator H(X|*) see MUI.m

if(nargin<1 || isempty(X))
  p=10;      %dimensionality of points
  n=10E2;    %sample size
  s1=1.0;    %scale factor
  X=s1*randn(p,n);
  Z=rand(1,n)>sum(X,1);
end

%initial bins
[hx,nx]=hist(X,M);

hx1=hist(X(Z==0),nx); hx1(hx1==0)=1; hx1=hx1/sum(hx1);
hx2=hist(X(Z==1),nx); hx2(hx2==0)=1; hx2=hx2/sum(hx2);

% figure(1),plot(nx,hx1,nx,hx2),pause(0.2)

idx=(hx>10);

kl=sum(log(hx1(idx)./hx2(idx)).*hx1(idx));

end