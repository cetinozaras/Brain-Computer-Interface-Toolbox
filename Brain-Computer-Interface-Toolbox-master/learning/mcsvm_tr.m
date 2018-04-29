classdef mcsvm_tr<handle
    
    properties(Access = protected)
    end
    properties(Access = private)
        eegsamples
        xvalthr=0.70;     %train-validation split
        testthr=0.1;      %train-validation--test split
        nnmax=10000;      %max number of examples to draw for training
        
    end
    properties(GetAccess = public,SetAccess=private)
    end
    properties(GetAccess = public,SetAccess=protected)
    end
    properties(Access = public)
        commonmode       %common mode modifier
        xvalsequential   %sequential/random train-validation split modifier
        datafiles
        predt
        postdt
        chidx
        ftid
        target
        ft
        ftmrk
        act_flgtest
        
    end
    methods(Access=private)
    end
    methods(Access=protected)
    end
    methods(Access=public)
        
        function Parameters(this)
            
            if isempty(this.xvalsequential)
                this.xvalsequential=false; end
            
            if nargin<5
                this.ftid=[]; end
            
            if nargin<6 || isempty(this.target)
                this.target=[1 2]; end
        end
        
        function PrepareFeatures(this)
            
            %% Prepare features
            fprintf('Preparing features...\n');
            
            %use precomputed features (if ft or ftmrk were given) or compute features
            if nargin<8 || isempty(this.ft) || isempty(this.ftmrk)
                [this.ft, this.ftmrk]=ftprep(this.datafiles,this.predt,this.postdt,this.chidx,this.commonmode,this.ftid);
            end
            
            %make features
            [this.eegsamples,this.ftmrk]=make_features(this.ft,this.ftmrk,this.ftid);
            
            %if trial-idx are passed, constrain samples to specified trials (ft.tridx)
            if isfield(this.ft,'tridx')
                this.eegsamples=this.eegsamples(this.ft.tridx,:);
                this.ftmrk=this.ftmrk(this.ft.tridx);
            end
        end
        
        
        function FinalizeData(this)
            %% Finalize data
            this.target=sort(this.target);
            ttidx=ismember(this.ftmrk,this.target);
            this.eegsamples=this.eegsamples(ttidx,:);
            mrktargets=this.ftmrk(ttidx);
            nn=size(this.eegsamples,1);
            
            fprintf('#########################\n');
            fprintf('Total samples %i\n',size(this.eegsamples,1));
            fprintf('Total features %i\n',size(this.eegsamples,2));
            fprintf('#########################\n');
            
            %training-validation/test-sets split
            if nargin<9 || isempty(this.act_flgtest)
                this.act_flgtest=rand(1,nn)<this.testthr;
            end
            
            
            %% Prepare features
            nt=length(this.target);
            osvm=cell(nt,nt);
            
            %training/validation-sets split
            if this.xvalsequential
                fprintf('Sequential x-validation split\n');
                act_flgtrain=((1:nn)/nn)<this.xvalthr;
            else
                fprintf('Random x-validation split\n');
                act_flgtrain=rand(1,nn)<this.xvalthr;
            end
            
            %form example sets
            %training exampels set
            idx=find(act_flgtrain & ~this.act_flgtest);
            idx=idx(randperm(length(idx)));
            idx=idx(1:min(length(idx),this.nnmax));
            train_examples=this.eegsamples(idx,:);
            train_targets=mrktargets(idx);
            
            %validation examples set
            idx=find(~act_flgtrain & ~this.act_flgtest);
            idx=idx(randperm(length(idx)));
            val_examples=this.eegsamples(idx,:);
            val_targets=mrktargets(idx);
            
            %test examples set
            idx=find(this.act_flgtest);
            idx=idx(randperm(length(idx)));
            test_examples=this.eegsamples(idx,:);
            test_targets=mrktargets(idx);
            
            
            %% train SVM's
            tic
            fprintf('Train %ix%i SVM models...\n',nt,nt);
            fprintf('Prepare %ix%i feature sets...\n',nt,nt);
            for i=2:nt
                for j=1:i-1
                    fprintf(' ranking features for pair (%i,%i)...\n',i,j);
                    
                    %training examples, only contain {i-j} pair
                    idx=ismember(train_targets,this.target([i,j]));
                    xexamples=train_examples(idx,:);
                    xtargets=train_targets(idx);
                    xtargets=(xtargets==this.target(i));
                    
                    [ftidx,ranks,nid]=parse_ftid(this.ftid,this.ft,xexamples,xtargets,[0,1]);
                    
                    %train SVM
                    fprintf(' training svm for pair (%i,%i)...\n',i,j);
                    options=optimset('MaxIter',10000);
                    if nid>0
                        %come back with given cutoff - just train SVM
                        warning off all
                        svm2=svmtrain(xexamples(:,ftidx),xtargets,'Method','LS',...
                            'QuadProg_Opts',options);
                        warning on all
                    else
                        %come back with given cutoff - just train SVM
                        dnn=25;     %initial num of features and the number increment step
                        dnn_stop=4; %number of feature number increments without improvement
                        %before stop
                        dnn_cnt=0;  %counter of feature number increments without improvement
                        dnn_mininc=2E-2; %minimal required increment
                        xsvm2=[];   %best SVM
                        xnid=[];    %best nid
                        xp=-[Inf,Inf,Inf];   %previous p values
                        for nid=dnn:dnn:length(ranks)
                            ftidx_=ftidx(1:nid);
                            warning off all
                            svm2=svmtrain(xexamples(:,ftidx_),xtargets,'Method','LS',...
                                'QuadProg_Opts',options);
                            warning on all
                            
                            %check performance on training set
                            xtest=svmclassify(svm2,xexamples(:,ftidx_));
                            p1=mean(xtargets==xtest);
                            
                            %check performance on validation set
                            idx=ismember(val_targets,this.target([i,j]));
                            xxexamples=val_examples(idx,:);
                            xxtargets=val_targets(idx);
                            xxtargets=(xxtargets==this.target(i));
                            
                            xtest=svmclassify(svm2,xxexamples(:,ftidx_));
                            p2=mean(xxtargets==xtest);
                            
                            
                            %check performance on test set
                            idx=ismember(test_targets,this.target([i,j]));
                            xxexamples=test_examples(idx,:);
                            xxtargets=test_targets(idx);
                            xxtargets=(xxtargets==this.target(i));
                            
                            xtest=svmclassify(svm2,xxexamples(:,ftidx_));
                            p3=mean(xxtargets==xtest);
                            
                            %evaluate stopping condition - no improvement for dnn_stop
                            %increments
                            if (xp(2)>p2+dnn_mininc || xp(3)>p3+dnn_mininc)
                                dnn_cnt=dnn_cnt+1;
                            else
                                xsvm2=svm2;
                                xnid=nid;
                                xp=[p1,p2,p3];
                                dnn_cnt=0;
                            end
                            
                            fprintf(' feature number search %i: (%g,%g,%g)...\n',nid,p1,p2,p3);
                            
                            if dnn_cnt>dnn_stop
                                break;
                            end
                        end
                        
                        %set best SVM out
                        svm2=xsvm2;
                        nid=xnid;
                        ftidx=ftidx(1:xnid);
                        
                        fprintf(' ===selected %i: (%g,%g,%g)...\n',xnid,xp);
                    end
                    
                    %read SVM model w2*x'-b2
                    b2=svm2.Bias;
                    w2=svm2.SupportVectors'*svm2.Alpha;
                    w2=w2.*svm2.ScaleData.scaleFactor';
                    b2=b2+svm2.ScaleData.shift*w2;
                    w2=-w2;
                    
                    
                    o=[];
                    o.ftidx=ftidx;
                    o.w2=w2;
                    o.b2=b2;
                    o.bbef2=0;
                    
                    osvm{i,j}=o;
                end
            end
            toc
            
            
            %check overall performance on training set
            xtest=ownclassify(osvm,train_examples);
            p1=mean(train_targets==xtest);
            fprintf('Training %g\n',p1);
            
        end
        
        function XValidation(this)
            %% X-validation
            %obtain mnSVM values
            vals1=ownclassify(osvm,val_examples);
            vals=val_targets;
            
            %check performance on validation set
            p2=sum(vals==vals1)/length(vals);
            fprintf('X-validation %g\n',p2);
            
            
        end
        
        function Test(this)
            %% Test
            %obtain SVM values
            vals1=ownclassify(osvm,test_examples);
            vals=test_targets;
            
            %check performance on test set
            p3=sum(vals==vals1)/length(vals);
            fprintf('Test %g\n',p3);
            
        end
        
        function FormSVMObject(this)
            %% Form SVM object
            svmObject=[];
            svmObject.target=this.target;
            svmObject.o=osvm;
            svmObject.predt=this.predt;
            svmObject.postdt=this.postdt;
            svmObject.ftid=this.ftid;
            
            %output train-validation-test errors
            pp=[p1 p2 p3];
            
            
            %classify using SVM model object
            function labels=ownclassify(osvm,xeegsamples)
                nn=size(osvm,1);    %number of 1-1 classifiers
                nt=size(xeegsamples,1);
                votes=zeros(nt,nn);  %1-1 classifiers' votes
                
                for ii=2:nn
                    for jj=1:ii-1
                        w2=osvm{ii,jj}.w2;
                        b2=osvm{ii,jj}.b2;
                        bbef2=osvm{ii,jj}.bbef2;
                        ftidx_=osvm{ii,jj}.ftidx;
                        
                        %obtain SVM values
                        valsd=-b2+xeegsamples(:,ftidx_)*w2;
                        vals1=(sign(valsd-bbef2)+1)/2;
                        
                        votes(vals1>0,ii)=votes(vals1>0,ii)+1;
                        votes(vals1==0,jj)=votes(vals1==00,jj)+1;
                    end
                end
                
                [g labels]=max(votes,[],2);
                labels=reshape(this.target(labels),[],1);
            end
            
        end
        
    end
end
