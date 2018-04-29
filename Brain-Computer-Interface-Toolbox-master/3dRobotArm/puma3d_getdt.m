%Computing dt-rotations in Puma3d robot for a forward movement.
function dt=puma3d_getdt(dX)
%dt=puma3d_getdt(dX)
% Compute dt2, dt3 and dt5 rotations for Puma3d robot for
% a forward longitudinal motion dX, expressed as percentile
% of the full longitudinal range of motion (0-100).
%
% Y.Mishchenko (c) 2015

%constant Z-level
c=1-cos(pi/6);

%range of motion
xmin=sin(pi/6);
xmax=sqrt(4-c^2);

%current position
ThetaOld = getappdata(0,'ThetaOld');
theta2old = ThetaOld(2)/180*pi+pi/2;
theta3old = ThetaOld(3)/180*pi+pi/2;
theta5old = ThetaOld(5)/180*pi;

Xold=sin(theta2old)+sin(theta2old+theta3old);
Xold=(Xold-xmin)/(xmax-xmin)*100;
xnew=max(0,min(100,Xold+dX));
x=xnew/100*(xmax-xmin)+xmin;

z=norm([x,c]);

t3=acos(z^2/2-1);
t2=acos(z/2)+atan(c/x);
t2=pi/2-t2;
t5=-(t2+t3-pi/2);

dt=[0 t2-theta2old t3-theta3old 0 t5-theta5old 0]/pi*180;

end