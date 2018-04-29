function o = nkExperimentMotor_3
%Freeform input monitor and EEG marker forwarder. Usage:
% o=nkExperimentMotor_3
%Use keys 'd' and 'l' to provide left/right motion input
%
%Y.Mishchenko (c) 2015


%set this to true for test run of UI
flgdebug=false;

%initial relaxation time, sec
twait=5;

%sampling frequency
sampFreq=200;

%% Initialize
%unique alphanumeric ID
idtag=[datestr(now,'yyyymmddHHMM') '.' dec2hex(randi(intmax('uint32'),'uint32'))];
%UI's graphic handles
hState=zeros(1,20);
%UI's figure
fig=1;


%% Prepare experiment's program and UI window
%prepare main window
if(fig == 0)
    fig = figure;
else 
    figure(fig)
end
clf
%set(fig, 'menubar', 'none');

%fixation point
annotation(fig,'ellipse',[0.485 0.519 0.040 0.040],...
  'FaceColor',[0 0 0]);

set(fig,'Position',[536 157 512 512],'Color',[1 1 1]);

%counter boxes
nleft=0;
nright=0;
hleft=annotation(fig,...
  'textbox',[0.399 0.535 0.104 0.053],...
  'String',{'0'},...
  'FontSize',36,...
  'LineStyle','none');
hright=annotation(fig,...
  'textbox',[0.566 0.535 0.104 0.053],...
  'String',{'0'},...
  'FontSize',36,...
  'LineStyle','none');

%% Initialize trigger port
global s1
if(~flgdebug)
  s1 = serial('COM3', 'BaudRate', 9600);
  fopen(s1);
end

%% Main loop
tic
update_state(99);
program=[ 90 0 twait 99 0 1 99 4 1 99 3 1 99 2 1 99 1 1];
rlmktimes=zeros(1,30000);
for ipos=1:3:18  
    cue=program(ipos);          %get next trial
    tbrk=program(ipos+1);
    tlength=program(ipos+2);
    
    pause(tbrk);                  %pause for break
    
    rlmktimes(ipos)=cue;        %record stimulus on time
    rlmktimes(ipos+1)=toc;
    
    if(~flgdebug)
      fprintf(s1,'B');            %send bas to marker port
    end

    update_state(cue);            %update UI
    
    pause(tlength);               %pause for stimulus
    
    rlmktimes(ipos+2)=toc;        %record stimulus off time
    
    if(~flgdebug)
      fprintf(s1,'S');            %send son to marker port
    end
end

ipos=ipos+2;
update_state(0);
while(true)
    k = waitforbuttonpress;
    key=get(gcf,'CurrentCharacter');
    
    %user quit/terminate    
    if(strcmp(key,'Q') || strcmp(key,'q'))
        break;
    end

    rlmktimes(ipos+1)=key;        %record stimulus on time
    rlmktimes(ipos+2)=toc;
    
    if(key=='d') 
      nleft=nleft+1;
    elseif(key=='l') 
      nright=nright+1;
    end
    update_state(key);            %update UI
    
    if(~flgdebug)
      fprintf(s1,'B');            %send bas to marker port
    end
        
    pause(1.0);
    
    rlmktimes(ipos+3)=toc;        %record stimulus off time
    
    if(~flgdebug)
      fprintf(s1,'S');            %send son to marker port
    end
    
    update_state(0);            %update UI
    
    ipos=ipos+3;                  %move to next trial    
end
update_state(92);

if(~flgdebug)
  fprintf(s1,'S');       %guarantee shut down marker port
  fclose(s1);
end


%% Wite data
rlmktimes=rlmktimes(1:ipos);    %truncate data to available

o=[];
o.idtag=idtag;
o.mktimes=rlmktimes;
o.marker=makeArray(rlmktimes,sampFreq);

%save data to backup file
fname=sprintf('odata-%s.mat',idtag);
save(fname,'o');

    %prep marker array
    function marker=makeArray(rlmktimes,sampFreq)
        marker=zeros(1,ceil(sampFreq*(rlmktimes(end)+5)));
        ipos=0;
        while(ipos<length(rlmktimes))
            cue=rlmktimes(ipos+1);
            idxbegin=ceil(rlmktimes(ipos+2)*sampFreq);
            idxend=ceil(rlmktimes(ipos+3)*sampFreq);
            
            marker(idxbegin:idxend)=cue;
            ipos=ipos+3;
        end
    end


    %update UI
    function update_state(cuestate)
        figure(fig)
        
        % clear all dynamical graphic elements
        for i=find(hState)
            if(hState(i)~=0)
                delete(hState(i));
                hState(i)=0;
            end
        end
        
        if(cuestate==0)
        elseif(ischar(cuestate))
          hState(1)=annotation(fig,...
              'textbox',[0.4737 0.6016 0.0908 0.123],...
              'String',{cuestate},...
              'FontSize',36,...
              'LineStyle','none'); 
            
          set(hleft,'String',{sprintf('%i',nleft)});  
          set(hright,'String',{sprintf('%i',nright)});
        elseif(cuestate==90 || cuestate==99)
            hState(1)=annotation(fig,'textbox',[0.1154 0.4845 0.7751 0.2437],...
                'String',{'Initial Relaxation','PLEASE RELAX'},...
                'FontSize',36,'BackgroundColor',[1 1 1],...
                'FitBoxToText','off',...
                'LineStyle','none');
        elseif(cuestate==91)
            hState(1)=annotation(fig,'textbox',[0.1154 0.4845 0.7751 0.2437],...
                'String',{'Break Time...','PLEASE RELAX'},...
                'FontSize',36,'BackgroundColor',[1 1 1],...
                'FitBoxToText','off',...
                'LineStyle','none');  
        elseif(cuestate==92)
            hState(1)=annotation(fig,'textbox',[0.1154 0.4845 0.7751 0.2437],...
                'String',{'Session Ended','THANK YOU!'},...
                'FontSize',36,'BackgroundColor',[1 1 1],...
                'FitBoxToText','off',...
                'LineStyle','none');              
        end
    end
end
