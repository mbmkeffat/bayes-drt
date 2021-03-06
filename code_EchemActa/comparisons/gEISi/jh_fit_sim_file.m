function [modality,betak,Rml,muml,wml,tl,Fl,Z_res] = jh_fit_sim_file(filename,fun,varargin)
%JH_FIT_SIM_FILE Fit a simulated data file with the specified impedance model.
%   Detailed explanation goes here

    parser = inputParser();
    addOptional(parser,'plot',true)
    parse(parser,varargin{:})
    
    % load data
    data_path = '../../../data/simulated';
    data = readtable(strcat(data_path,'/',filename));
    data.w = data.Freq*2*pi;
    mdata = table2array(data(:,{'w' 'Zreal' 'Zimag'}));
    
    % configure for kernel function
    functionHandle=functions(fun);
    if strcmp(functionHandle.function,'DRT') || strcmp(functionHandle.function,'transmissiveDDT')
        % fit with abbreviated syntax
        start = datetime;
        [modality,betak,Rml,muml,wml,...
        betakn,Rmln,mumln,wmln,...
        wen,...
        tl,Fl]=invertEIS(fun,mdata);
        fin = datetime;
        disp(['Run time: ',num2str(minutes(fin-start)),' minutes'])
    elseif strcmp(functionHandle.function,'blockingDDT')
        Rinf=0; R1=2; tau1=1e-3;
        betak=Rinf;
        Rtaul=[R1,tau1];
        mue=NaN;
        distType = {'parallel'};

        start = datetime;
        [modality,betak,Rml,muml,wml,...
        betakn,Rmln,mumln,wmln,...
        wen,...
        tl,Fl]=invertEIS(fun,mdata,distType,betak,Rtaul,mue);
        fin = datetime;
        disp(['Run time: ',num2str(minutes(fin-start)),' minutes'])
    elseif strcmp(functionHandle.function,'jh_DRT_TpDDT')
        Rinf=1; R1=1; R2=1;
        tau1 = 10^(str2double(filename(6:7)));
        tau2 = 0.1;
        betak=Rinf;
        Rtaul=[R1,tau1; R2, tau2];
        mue=NaN;
        distType = {'series' 'parallel'};

        start = datetime;
        [modality,betak,Rml,muml,wml,...
        betakn,Rmln,mumln,wmln,...
        wen,...
        tl,Fl]=invertEIS(fun,mdata,distType,betak,Rtaul,mue);
        fin = datetime;
        disp(['Run time: ',num2str(minutes(fin-start)),' minutes']) 
    elseif strcmp(functionHandle.function,'jh_DRT_TpDDT_BpDDT')
        Rinf=1; R1=1; R2=1; R3=1;
        tau1 = 1e-5;
        tau2 = 1e-2;
        tau3 = 0.1;
        betak=Rinf;
        Rtaul=[R1,tau1; R2, tau2; R3, tau3];
        mue=NaN;
        distType = {'series' 'parallel' 'parallel'};

        start = datetime;
        [modality,betak,Rml,muml,wml,...
        betakn,Rmln,mumln,wmln,...
        wen,...
        tl,Fl]=invertEIS(fun,mdata,distType,betak,Rtaul,mue);
        fin = datetime;
        disp(['Run time: ',num2str(minutes(fin-start)),' minutes'])
        
    end
    
    % get impedance fit
    functionHandle=functions(fun);
    if strcmp(functionHandle.function,'DRT')
        distType = {'series'};
    elseif strcmp(functionHandle.function,'transmissiveDDT')
        distType = {'parallel'};
    elseif strcmp(functionHandle.function,'blockingDDT')
        distType = {'parallel'};
    end
    Zhat_full = exactModel(fun,betak,Rml(:,2),muml(:,2),wml(:,2),modality,distType);
    Zhat = Zhat_full(:,2);
    Z_res = array2table([data.Freq real(Zhat) imag(Zhat)],...
        'VariableNames',{'freq' 'Zreal' 'Zimag'});

    % show plot if requested
    if parser.Results.plot
        
        %% 1st dist plot
        figure()
        
        % load true DRT
        filesplit = strsplit(filename,'_') ;
        circ = filesplit{2};
        gfile = strcat('gamma_',circ,'.csv');
        gtrue = readtable(strcat(data_path,gfile));
        
        % plot true DRT
        plot(log(gtrue.tau),gtrue.gamma,'k'); hold('on')
        
        % plot point estimate and CI
        FlTemp=Fl{1};
        plot(tl{1},FlTemp(2,:),'r','LineWidth',1)
        plot(tl{1},FlTemp(1,:),'r-.','LineWidth',1)
        plot(tl{1},FlTemp(3,:),'r-.','LineWidth',1)
        
        % Labels
        xlabel('t')
        ylabel('F_1(t)')
        legend('True Distribution','Inversion Output')
        
        % title
        suptitle(strcat(filename,' DRT'))
        
        %% TP-DDT plot
        if strcmp(functionHandle.function,'jh_DRT_TpDDT') || strcmp(functionHandle.function,'jh_DRT_TpDDT_BpDDT')
            figure()

            % plot true TP-DDT
            plot(log(gtrue.tau),gtrue.ftp,'k'); hold('on')

            % plot point estimate and CI
            FlTemp=Fl{2};
            plot(tl{2},FlTemp(2,:),'r','LineWidth',1)
            plot(tl{2},FlTemp(1,:),'r-.','LineWidth',1)
            plot(tl{2},FlTemp(3,:),'r-.','LineWidth',1)

            % Labels
            xlabel('t')
            ylabel('F_1(t)')
            legend('True Distribution','Inversion Output')

            % title
            suptitle(strcat(filename,' TP-DDT'))
        end
        
        %% BP-DDT plot
        if strcmp(functionHandle.function,'jh_DRT_TpDDT_BpDDT')
            figure()

            % plot true BP-DDT
            plot(log(gtrue.tau),gtrue.fbp,'k'); hold('on')

            % plot point estimate and CI
            FlTemp=Fl{3};
            plot(tl{3},FlTemp(2,:),'r','LineWidth',1)
            plot(tl{3},FlTemp(1,:),'r-.','LineWidth',1)
            plot(tl{3},FlTemp(3,:),'r-.','LineWidth',1)

            % Labels
            xlabel('t')
            ylabel('F_1(t)')
            legend('True Distribution','Inversion Output')

            % title
            suptitle(strcat(filename,' BP-DDT'))
        end
        
        %% Bode plot
        figure()
        axr = subplot(1,2,1);
        axi = subplot(1,2,2);
        
        % plot point estimate only
%         Zhat = Zhat_full(:,2);
%         Zhat_lo = Zhat_full(:,1);
%         Zhat_hi = Zhat_full(:,3);
        
        % load true impedance
        Zfile = strcat('Z_',circ,'_noiseless.csv');
        Ztrue = readtable(strcat(data_path,Zfile));
        
        % plot real impedance
        plot(axr,log10(data.Freq),real(Zhat),'r','DisplayName','Fit')
        hold(axr,'on')
%         plot(axr,log10(data.Freq),real(Zhat_lo),'r-.','DisplayName','')
%         plot(axr,log10(data.Freq),real(Zhat_hi),'r-.','DisplayName','')
        scatter(axr,log10(data.Freq),data.Zreal,10,'k',...
            'DisplayName','Data')
        plot(axr,log10(data.Freq),Ztrue.Zreal,'k--','DisplayName','True')
        xlabel(axr,'log(f)')
        ylabel(axr,"Z'")
        legend(axr)
        
        % plot imag impedance
        plot(axi,log10(data.Freq),imag(Zhat),'r','DisplayName','Fit')
        hold(axi,'on')
%         plot(axi,log10(data.Freq),imag(Zhat_lo),'r','DisplayName','')
%         plot(axi,log10(data.Freq),imag(Zhat_hi),'r','DisplayName','')
        scatter(axi,log10(data.Freq),data.Zimag,10,'k',...
            'DisplayName','Data')
        plot(axi,log10(data.Freq),Ztrue.Zimag,'k--','DisplayName','True')
        xlabel(axi,'log(f)')
        ylabel(axi,"Z''")
        legend(axi)
        
        % title
        suptitle(filename)
        
        
    end
    
end

