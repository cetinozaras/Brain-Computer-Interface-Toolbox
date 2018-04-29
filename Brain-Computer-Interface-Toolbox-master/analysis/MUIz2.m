function mu=MUIz2(X,Z,M)
%mui=MUIz2(X,Z,M)
%Mutual information estimation for a 1D continuous + discrete variables.
% X should be 1 x n array of n observations of the realizations of a
% 1D continuous-valued random variable X, Z should be a 1 x n array of
% the observations of a 1D discrete-valued random variable Y. The
% number of the observations of both X and Z MUST be the same, n. M
% is the number of bins to use in histograms
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
[hx,nx]=hist(X,M); hx(hx==0)=1; px=hx/sum(hx); idx=(hx>10);
w=nx(2)-nx(1);        %bin width

HX=-sum(log(px(idx)).*px(idx))-log(w);

HXZ=0;
ZZ=unique(Z);
for i=ZZ
    p=sum(Z==i)/length(Z);
    hx=hist(X(Z==i),nx); hx(hx==0)=1; hx=hx/sum(hx);
    
    hxz=-sum(log(hx(idx)).*hx(idx))-log(w);
    HXZ=HXZ+hxz*p;
end

mu=HX-HXZ;

end