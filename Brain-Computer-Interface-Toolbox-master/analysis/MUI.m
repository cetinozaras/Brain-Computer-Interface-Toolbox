function [mui,HXY,HX,HY]=MUI(X,Y)
%mui=MUI(X,Y)
%Mutual information estimator for two continuous variables.
% X should be p1 x n array of n observations of the realizations of a 
% p1-dimensional continuously-valued random variable X, Y should be a 
% p2 x n array of the observations of a p2-dimensional continuously-valued 
% random variable Y. The number of the observations of both X and Y MUST 
% be the same, n.
%
% If X is empty or absent, returns a hard-wired test result.
%
% Y.Mishchenko (c) 2015

%Based on Kozachenko & Leonenko'1987; Singh, Misra, et al'2003
%Mutual Information of two random variables X and Y is
% MUI(X,Y)=H(X)+H(Y)-H(X,Y)=H(Y)-H(Y|X)=H(X)-H(X|Y)
%Entropy H(X) is
% H(X)=E[ln(pdf(X))]
%where pdf(X) is the probability density function of X and E[.] is
%expectation value;
%MUI shows change in entropy (uncertainty) of the values of variable 
%Y if the value of variable X is known (and vice versa);
%
%KL estimator is
% EH=pE[ln r]+ln{pi^(p/2)/gamma(p/2+1)}-psi(1)+log(n-1)
%where r is nearest neighbor distance in n-sample from pdf(x), 
%p is dimension of data points, gamma(.) is gamma-function, 
%psi(.) is psi-function
%SMHFD estimator is
% EH=pE[ln rk]+ln{pi^(p/2)/(k*gamma(p/2+1))}-psi(k)+ln(k)+ln(n)
%where rk is k-nearest neighbor distance in n-sample from pdf(x),
%and other symbols as defined for KL estimator.
%
%These estimators are asymptotically convergent whenever 
%E[ln(pdf(X))]=H[X] and also var(ln(pdf))=E[ln(pdf(X))^2]-H[X] 
%are finite.
%
%Some finite-sample properties:
%for EH(X,Y) to correctly reproduce H(X,Y), it is necessary that the 
%typical spacings  between both X and Y are of same order of magnitude,
%if the typical spacings between X and Y are drastically different, 
%it is natural to expect H(X,Y) to relax to either H(X) or H(Y), as 
%the distribution of ln r(X) or ln r(Y) would stay essentially 
%unaffected by the presence of much sparser points from Y or X, and 
%EH(X,Y)->(p_X+p_Y)/p_X EH(X), roughly, for example.
%In this case, to recover convergence n may need to be greatly increased.
%To control for this effect, it is recommended to build MUI gradually for
%increasing sample size n, and observe the estimator convergence behavior.
%
%The above estimators are for continuous random variables and cannot be 
%applied to discreate random variables. In particular, for discrete random
%variables the nearest neighbor distance is nearly guaranteed to always be
%zero. The summation over discrete parts of the entropy calculation needs
%to be carried out explicitly.
%
%The above estimators cannot be applied to the case of MUI(X,Y=X) or 
%equivalent since pdf(Y=X|X) in continuous case is singular and therefore
%infinite, likewise H(X,Y=X) in continuous case is (minus) singular. 
%Thus we have in continuous case essentially MUI(X,Y=X)=H(X)-(-inf)=inf.

k=5;        %kth nearest neighbor choice

if(nargin<1 || isempty(X))
  p=1;      %dimensionality of points
  n=10E2;    %sample size
  s1=1;      %scale factor
  s2=0.1;
  X=s1*randn(p,n);
  Y=X+s2*randn(p,n);
end

HX=H(X);
HY=H(Y);
HXY=H([X;Y]);
fprintf('EHX %g\nEHY %g\nEHXY %g\n',HX,HY,HXY);

mui=HX+HY-HXY;
fprintf('MUI %g\n',mui);

  function EH=H(X)
    %calculate entropy for X
    p=size(X,1);
    n=size(X,2);    
    
    %matrix of all-to-all distances
    D=dist(X);
    
    %sort along 2nd dimension (rows)
    D=sort(D,2);
    
    %pick out k-nearest neighbor distances
    RK=D(:,k+1);
    
    %form E[H]
    EH=p/n*sum(log(RK))+log(pi^(p/2)/(k*gamma(p/2+1)))-psi(k)+log(k)+log(n);
  end

end