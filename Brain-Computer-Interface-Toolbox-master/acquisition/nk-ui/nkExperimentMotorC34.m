function o = nkExperimentMotorC34(maxcue,session_num,trial_num,break_time)
%Usage
% o=nkExperimentMotorC34(num_cues,num_sessions,num_trials,break_time)
% num_cues is the number of motion imageries to be used; 
% included:
%   left-hand 
%   right-hand
%   passive 
%   left-foot 
%   right-foot 
%   tongue
% num_session is the number of sessions;
% num_of_trials is the number of trials per one session;
% break_time is the break time between sessions, in seconds.
%
%Y.Mishchenko (c) 2015


%set this to true for test run of UI
flgdebug=true;

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


%% Prepare program and UI window
program=prepare_prg;
hState(:)=0;

if(fig == 0)
    fig = figure;
else 
    figure(fig)
end
clf
%set(fig, 'menubar', 'none');
set(fig,'Position',[309 217 676 677],'Color',[1 1 1]);
axis([0 1 0 1]);
axis off;

imgnames={'lefthand.png','righthand.png','pass.png','rightfoot.png',...
    'leftfoot.png','tongue.png'};
imgs=cell(1,length(imgnames));
maps=cell(1,length(imgnames));
warning off all
for i=1:length(imgnames)
    [imgs{i} maps{i}]=imread(imgnames{i});
end
[imgwait mapwait]=imread('wait.png');
warning on all

%% Initialize marker port
global s1
if(~flgdebug)
  s1 = serial('COM3', 'BaudRate', 9600);
  fopen(s1);
end

%% Main loop
ipos=0;
rlmktimes=zeros(size(program));
update_state(99);
tic
while(ipos<length(program))
    cue=program(ipos+1);          %get next trial
    tbrk=program(ipos+2);
    tlength=program(ipos+3);
    
    pause(tbrk);                  %pause for break
    
    rlmktimes(ipos+1)=cue;        %record stimulus on time
    rlmktimes(ipos+2)=toc;
    update_state(cue);            %update UI
    
    if(~flgdebug)
      fprintf(s1,'B');                %send bas to marker port
    end
    
    pause(tlength);               %pause for stimulus
    
    rlmktimes(ipos+3)=toc;        %record stimulus off time
    
    if(cue~=99 && cue~=92)
        update_state(0);          %update UI
    end

    if(~flgdebug)
      fprintf(s1,'S');                %send son to marker port
    end
    
    ipos=ipos+3;                  %move to next trial
    
    %user quit/terminate
    key=get(gcf,'CurrentCharacter');
    if(strcmp(key,'Q') || strcmp(key,'q'))
        break;
    end
end
if(~flgdebug)
  fprintf(s1,'S');       %guarantee shut down marker port
  fclose(s1);
end



%write data
rlmktimes=rlmktimes(1:ipos);    %truncate data to available

o=[];
o.idtag=idtag;
o.mktimes=rlmktimes;
o.marker=makeArray(rlmktimes,sampFreq);

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

    %UI program
    %program is array of tripples of the form
    %[cue break duration cue break duration ... (continues)]
    function program=prepare_prg
        program=zeros(1,20000);
        
        %syncronization sequence
        ipos=0;        
       
        %initial relaxation
        program(ipos+1:ipos+3)=[90 0 twait];
        ipos=ipos+3;
        
        program(ipos+1:ipos+15)=[99 5 1 99 4 1 99 3 1 99 2 1 99 1 1];
        ipos=ipos+15;
%         program(ipos+1:ipos+12)=[99 4 1 99 3 1 99 2 1 99 1 1];
%         ipos=ipos+12;
%         program(ipos+1:ipos+9)=[99 3 1 99 2 1 99 1 1];
%         ipos=ipos+9;        
        
        for s=1:session_num
            for k=1:trial_num
                %cue interval, random 1.5-2.5 sec
                tbrk=1*rand+1.5;
                %cue length
                tact=1;
                %current cue
                cue=randi(maxcue);
                    
                program(ipos+1:ipos+3)=[cue tbrk tact];
                ipos=ipos+3;
            end
            
            if(s<session_num)
                program(ipos+1:ipos+3)=[91 0 break_time];
                ipos=ipos+3;
            end
        end
        
        program(ipos+1:ipos+3)=[92 0 1];
        ipos=ipos+3;
        
        program=program(1:ipos);
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
            hState(1)=image([0.3,0.7],[0.3,0.7],imgwait);
            axis([0 1 0 1]),axis off
        elseif(cuestate>0 && cuestate<=length(imgs))
            hState(1)=imshow(imgs{cuestate},maps{cuestate});
        elseif(cuestate==90 || cuestate==99)
            hState(1)=annotation(fig,'textbox',[0.1154 0.4845 0.7751 0.2437],...
                'String',{'Initial Relaxation','PLEASE RELAX'},...
                'FontSize',50,...
                'FitBoxToText','off',...
                'LineStyle','none');
        elseif(cuestate==91)
            hState(1)=annotation(fig,'textbox',[0.1154 0.4845 0.7751 0.2437],...
                'String',{'Break Time...','PLEASE RELAX'},...
                'FontSize',50,...
                'FitBoxToText','off',...
                'LineStyle','none');  
        elseif(cuestate==92)
            hState(1)=annotation(fig,'textbox',[0.1154 0.4845 0.7751 0.2437],...
                'String',{'Session Ended','THANK YOU!'},...
                'FontSize',50,...
                'FitBoxToText','off',...
                'LineStyle','none');              
        end
    end
end
