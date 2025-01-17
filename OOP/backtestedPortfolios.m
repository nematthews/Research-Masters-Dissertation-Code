% backtestedPortfolios class definition
classdef backtestedPortfolios 
    properties (SetAccess = private) % Can only change property through a method

        PortfoliosList      cell            % cell array
        AssetList           cell            % cell array
        Attributions        table           % structure
        RollingPerformance  timetable       % Timetable
        HSFP_Prs            = []            % Empty for storage
        NumPortfolios       (1,1) double    % scalar
        DataType            (1,1) string =  'backtestedPortfolios'
        ExcessReturns       double
        GeometricSR         double
        Benchmark_PRets     double
        MaxDrawDowns        table           = []
        OptPortWts          cell            % Cell array of TTs with dif dimensions
        Realised_tsPRet_TT  timetable        
    end
    properties  % Able to be set by user when creating a class object

        WindowLength        (1,1) double = 36
        Returns             timetable
        Invariants          timetable
        Signals             timetable           % Timetable
        RegLambda           (1,1) double = 0    % Default (no regularisation)
        MaxDD_cal           (1,1) string {mustBeMember(MaxDD_cal,{'on',...
            'off'})} =  'off'   % Default (no max Drawdown calc)
        % if MaxDD_cal set to 'on': calculate max drawdown (might fail for 
        % certain cases sense can be turned off)
        WinsorStd           double {mustBeNonnegative} = []  % if empty don't winsorise
        MVWts_lb            (1,:) double        % vector of lower bounds
        MVWts_ub            (1,:) double        % Vector of upper bounds
        CashConstraint   (1,1) double {mustBeNonnegative} = 1 % Default no constriant
        Method              (1,1) string {mustBeMember(Method,{'none', ...
            'rolling_w','exp_decay','crisp', 'kernel', ...
            'e_pooling', 'ew_ensemble', 'cb_ensemble'})} = 'none'
        HSFPparameters  HSFPparameters  %structure/class
        PSRbenchmark        (1,1) string {mustBeMember(PSRbenchmark,{'zeroSkill',...
            'strategyWise'})} =  'zeroSkill'
    end

    methods

        % 1.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%% CONSTRUCTOR FUNCTION %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function backtestedPortfolios = backtestedPortfolios(Returns,Invariants,...
                WindowLength,MVWts_lb,MVWts_ub,Method,Signals,HSFPparameters)
            if  (nargin == 8)
                backtestedPortfolios.Returns = Returns;
                backtestedPortfolios.Invariants = Invariants;
                backtestedPortfolios.WindowLength = WindowLength;
                backtestedPortfolios.MVWts_lb = MVWts_lb;
                backtestedPortfolios.MVWts_ub = MVWts_ub;
                backtestedPortfolios.Method = Method;
                backtestedPortfolios.Signals = Signals;
                backtestedPortfolios.HSFPparameters = HSFPparameters;
            elseif (nargin > 0)
                error("You need to provide all 8 required inputs " + ...
                    "(or leave empty for default values): " + ...
                    "Returns, WindowLength, MVWts_lb, MVWts_ub, Method" + ...
                    ", Signals, HSFPparameters. ")
            end
        end

        % 2.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%% backtest_analysis Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function objCopy = copy(obj)
            % Create a new object as a copy of the original object
            objCopy = backtestedPortfolios();
        
            % Copy properties
            objCopy.HSFPparameters = obj.HSFPparameters;
            objCopy.WindowLength = obj.WindowLength;
            objCopy.MVWts_lb = obj.MVWts_lb;
            objCopy.MVWts_ub = obj.MVWts_ub;
            objCopy.Returns = obj.Returns;
            objCopy.Invariants = obj.Invariants;
            objCopy.Method = obj.Method;
            objCopy.Signals = obj.Signals;
            objCopy.CashConstraint = obj.CashConstraint;
            objCopy.WinsorStd = obj.WinsorStd;
            objCopy.RegLambda = obj.RegLambda;
        
            % Copy other properties as needed
        end



        function [backtestedPortfolios] = OOPbacktest_analysis(backtestedPortfolios)

            %% NOTE: This function is very use specific to this project.
            % It was created to streamline the project code therefore does not
            % currently generalise well. Function can be made more streamline but currently
            % coded with time constraints in mind.
            %
            %% Primary INPUT:
            %% backtestedPortfolios
            % - self defined class object with properties as listed below
            % with their expected data type.
            %
            %% Set/Locked Properties:
            % PortfoliosList      cell            % cell array
            % AssetList           cell            % cell array
            % Attributions        table           % structure
            % RollingPerformance  timetable       % Timetable
            % HSFP_Prs            = []            % Empty for storage
            % NumPortfolios       (1,1) double    % scalar
            % DataType            (1,1) string =  'backtestedPortfolios'
            % ExcessReturns       double
            % GeometricSR         double
            % Benchmark_PRets     double
            % MaxDrawDowns        table           = []
            % OptPortWts          cell            % Cell array of TTs with dif dimensions
            % Realised_tsPRet_TT  timetable  
            %
            %% Free properties that users needs to assign and can adjust
            %
            % WindowLength        (1,1) double = 36
            % Returns             timetable
            % Invariants          timetable
            % Signals             timetable           % Timetable
            % RegLambda           (1,1) double = 0    % Default (no regularisation)
            % WinsorStd           double {mustBeNonnegative} = []  % if empty don't winsorise
            % MVWts_lb            (1,:) double        % vector of lower bounds
            % MVWts_ub            (1,:) double        % Vector of upper bounds
            % CashConstraint      (1,1) double {mustBeNonnegative} = 1 % Default no constriant
            % Method              (1,1) string {mustBeMember(Method,{'none', ...
            %     'rolling_w','exp_decay','crisp', 'kernel', ...
            %     'e_pooling', 'ew_ensemble', 'cb_ensemble'})} = 'none'
            % HSFPparameters      HSFPparameters  %structure/class
            % PSRbenchmark        (1,1) string {mustBeMember(PSRbenchmark,{'zeroSkill',...
            %     'strategyWise'})} =  'zeroSkill'
            %
            %
            %% DEFINE ALL PROPERTIES
            %
            % See also: HSFPparameters.m as self-defined structure/class
            %
            % NB:
            % HS-FP method options:   
            %            - none (default) NOTE: this is not defined 
            %                below as it is only used in backtest fn to 
            %                rather use normal mean and cov.         
            %            - rolling_w
            %            - exp_decay
            %            - crisp
            %            - kernel
            %            - e_pooling
            %            - ew_ensemble
            %            - cb_ensemble
            %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %% Example: HSFPparameters object parameters expected  
            % (this case window needed for rolling_w)
            %
            % 
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % NB NOTE: if HSFPparameters.method = 'rolling_w' ensure w_len < Window.

            % Author: Nina Matthews (2023)

            % $Revision: 1.1 $ $Date: 2024/01/18 10:24:01 $ $Author: Nina Matthews $


            %% Data Management
            Window = backtestedPortfolios.WindowLength;
            backtestedPortfolios.PortfoliosList = {'EW (CM)', 'MVSR max',...
                'BalFund (BH)', 'HRP', ...
                'BalFund (CM)', 'ALSI', 'ALBI', 'Cash'};
            %% Winsorise Returns
            if ~isempty(backtestedPortfolios.WinsorStd)
                Return_matrix = table2array(backtestedPortfolios.Returns);
                [wx,~,~,~] = winsorise(Return_matrix,backtestedPortfolios.WinsorStd);
                winsorisedRet_TT = array2timetable(wx,'RowTimes',backtestedPortfolios.Returns.Time);
                winsorisedRet_TT.Properties.VariableNames = backtestedPortfolios.Returns.Properties.VariableNames;
                backtestedPortfolios.Returns = winsorisedRet_TT;
        
            end 
            %%
            returns_data = backtestedPortfolios.Returns;
            invariant_data = backtestedPortfolios.Invariants;
            Cash = backtestedPortfolios.Returns(:,'Cash');
            signals_data = backtestedPortfolios.Signals;

            % Sub setting for Balance Fund
            tickersToExtract = {'JALSHTR_Index', 'Cash','ALB_Index'};
            BF_BH_TT = returns_data(:, tickersToExtract);
            returns_data = removevars(returns_data,'JALSHTR_Index');

            % Subset for HRP (remove cash as we have hard allocation to cash)
            if backtestedPortfolios.CashConstraint ~= 1
                % if not set to default of non cash constraint
                HPR_Ret_TT = removevars(returns_data,"Cash");
            else
                HPR_Ret_TT = returns_data;
            end
            %% 1. Set up storage and initialise weights for Backtest %%%%%%%%%%%

            %###### initialize inputs:
            [m,n]=size(returns_data); % size of full data set
            % Window = 36;
            backtestedPortfolios.AssetList = returns_data.Properties.VariableNames;
            % Rfr = mean(returns_data.JIBA3M_Index);

            %###### initialize storage:
            % ### 0. covariance condition numbers
            cov_con_n = zeros(m,1);
            % ### 0. SR excess return for each portfolio @ each t step (currently 5
            % portfolios)
            SR_dif_t = zeros(m,5);
            % ### 1. Equally Weighted (EW)###
            Overlap_tsEW_Wts0 = eqweight(returns_data);
            Overlap_tsEW_Wts = zeros(m,n);
            Overlap_tsEW_PRet = zeros(m,1); % storage for Portfolio Ret
            % ### 2. SR Maximizing ###
            Overlap_tsSR_Wts = zeros(m,n); % storage for Portfolio Weights
            Overlap_tsSR_PRet = zeros(m,1);
            % ### 3. Balanced Fund Buy-Hold ###
            Overlap_tsBH_Wts = [0.60,0.05,0.35]; % [equity, cash, bonds] - balanced fund 60:5:35
            % Overlap-window weights beginning of months
            Overlap_tsBH_Wts0 = zeros(m,3);   % for t-th month
            % Overlap-window weights end of months
            Overlap_tsBH_WtsEnd = zeros(m,3);
            Overlap_tsBH_PRet = zeros(m,1);
            % ### 4. HRP ###
            [j,k] = size(HPR_Ret_TT);
            Overlap_tsHRP_Wts = zeros(j,k);
            Overlap_tsHRP_PRet = zeros(j,1);
            % ### 5. Balanced Fund Constant Mix (CM) ###
            Overlap_tsCM_Wts0 = [0.60,0.05,0.35]; % [equity, cash, bonds] - balanced fund 60:5:35
            Overlap_tsCM_Wts = zeros(m,3);
            Overlap_tsCM_PRet = zeros(m,1);

            %% Set weight constraints for asset classes
            
            %%% if staement to check if CC = 1 then dont incoporte
            %%% constraint
            if backtestedPortfolios.CashConstraint == 1
                backtestedPortfolios.MVWts_lb = [0 0 0 0 0];
                backtestedPortfolios.MVWts_ub = [1 1 1 1 1];
            else
                backtestedPortfolios.MVWts_lb = [0 0 0 0 backtestedPortfolios.CashConstraint];
                backtestedPortfolios.MVWts_ub = [1 1 1 1 backtestedPortfolios.CashConstraint];
            end
            if isempty(backtestedPortfolios.MVWts_lb)
                backtestedPortfolios.MVWts_lb = zeros(1,n);
            end

            if isempty(backtestedPortfolios.MVWts_ub)
                backtestedPortfolios.MVWts_ub = ones(1,n);
            end

            %% 2. Begin backtest window shifts %%%%%%%%%%%
            for t=Window:m-1
                %%%%% need new stats of new window each time %%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Instead of adding the conventional moments calc into
                % 'backtest_moments.m' we leave it independent so that the backtest still
                % functions if the file dependency fails for some reason.

                % Sets 'none' as default if backtest_object.method is not defined
                if strcmp(backtestedPortfolios.Method, 'none') || isempty(backtestedPortfolios.Method)
                    % Geometric Mean:
                    m_t = geo_ave(returns_data{1+t-Window:t-1,:});
                    % Arithmetic Covariance:
                    cov_t = cov(returns_data{1+t-Window:t-1,:});
                    cov_HRP_t = cov(HPR_Ret_TT{1+t-Window:t-1,:});
                else
                    % Shift windows of returns and signals for HSFP each loop
                    backtestedPortfolios.Returns = returns_data(1+t-Window:t-1, :);
                    backtestedPortfolios.Invariants = invariant_data(1+t-Window:t-1, :);
                    backtestedPortfolios.Signals = signals_data(1+t-Window:t-1, :);
                    % Need to calc pr for each window (but type stays the same)
                    [m_t, cov_t,backtestedPortfolios.HSFP_Prs] = backtest_moments(backtestedPortfolios);

                    %%% For HRP we need sperate HSFP estimations for decreased assets
                    % Shift windows of returns and signals for HSFP each loop
                    backtestedPortfolios.Returns = HPR_Ret_TT(1+t-Window:t-1, :);
                    % Need to calc pr for each window (but type stays the same)
                    [~, cov_HRP_t,~] = backtest_moments(backtestedPortfolios);
                end

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Regularization parameter (lambda)
                % If reg_lambda is specified regularise cov matrix else skip:
                if backtestedPortfolios.RegLambda ~= 0
                    % Identity matrix of the same size as Cov
                    n = size(cov_t,1);  % Assuming S is a square matrix
                    I = eye(n);
                    I_HRP = eye(size(cov_HRP_t,1));
                    % Compute the regularized covariance matrix (R)
                    cov_t = cov_t + backtestedPortfolios.RegLambda * I;
                    cov_HRP_t = cov_HRP_t + backtestedPortfolios.RegLambda * I_HRP;
                end

                % Checking condition number of cov at each t:
                cov_con_n(t,:) = cond(cov_t);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                %%%%% WEIGHTINGS Generation %%%%%%
                % 1. EW
                % initialise wts as equally weighted
                Overlap_tsEW_Wts(t,:) = Overlap_tsEW_Wts0; % Constant Mix (CM)

                % 2. SR
                % initialise wts as equally weighted
                %     Overlap_tsSR_Wts(t,:) = maxsr(AssetList, m_t,cov_t, returns_data.Cash(t));

                Overlap_tsSR_Wts(t,:) = maxsr(m_t,cov_t, ...
                    returns_data.Cash(t-1,:),backtestedPortfolios.MVWts_lb, ...
                    backtestedPortfolios.MVWts_ub);

                % 3. Balanced BH
                % initialise wts as equally weighted
                Overlap_tsBH_Wts0(Window,:) = Overlap_tsBH_Wts; % initial weights

                % 4. HRP
                Overlap_tsHRP_Wts(t,:) = hrpestimate(cov_HRP_t)';

                % 5. Balanced CM
                % 3. Rebalance weighs
                Overlap_tsCM_Wts(t,:) = Overlap_tsCM_Wts0; % Constant Mix (CM)

                %%%%%%%%%%%% PORT RETURNS %%%%%%%%%%%%%
                % 1. EW
                Overlap_tsEW_PRet(t+1,:) = Overlap_tsEW_Wts(t,:) * transpose(returns_data{t+1,:});
                % SR excess Ret
                SR_dif_t(t+1,1) =  Overlap_tsEW_PRet(t+1,:) - returns_data.Cash(t+1,:);

                % 2. SR
                Overlap_tsSR_PRet(t+1,:) =  Overlap_tsSR_Wts(t,:) * transpose(returns_data{t+1,:});
                % SR excess Ret
                SR_dif_t(t+1,2) =  Overlap_tsSR_PRet(t+1,:) - returns_data.Cash(t+1,:);

                % 3. Balanced BH
                Overlap_tsBH_PRet(t+1,:) = Overlap_tsBH_Wts0(t,:) * transpose(BF_BH_TT{t+1,:});
                % SR excess Ret
                SR_dif_t(t+1,3) =  Overlap_tsBH_PRet(t+1,:) - returns_data.Cash(t+1,:);

                % 4. HRP
                Overlap_tsHRP_PRet(t+1,:) = Overlap_tsHRP_Wts(t,:) * transpose(HPR_Ret_TT{t+1,:});
                % SR excess Ret
                SR_dif_t(t+1,4) =  Overlap_tsHRP_PRet(t+1,:) - returns_data.Cash(t+1,:);

                % 5. Balanced CM
                Overlap_tsCM_PRet(t+1,:) = Overlap_tsCM_Wts(t,:) * transpose(BF_BH_TT{t+1,:});
                % SR excess Ret
                SR_dif_t(t+1,5) =  Overlap_tsCM_PRet(t+1,:) - returns_data.Cash(t+1,:);


                %%%%% UPDATE BH %%%%%%%
                % Calc month end weight
                Overlap_tsBH_WtsEnd(t,:) = (BF_BH_TT{t,:}.*Overlap_tsBH_Wts0(t,:))+ Overlap_tsBH_Wts0(t,:);
                % Calc month (i+1) weights
                Overlap_tsBH_Wts0(t+1,:) = Overlap_tsBH_WtsEnd(t,:)/sum(Overlap_tsBH_WtsEnd(t,:));
            end


            %% 3. Alternative Benchmarks: ALSI & ALBI & Cash (JIBA3M) %%%%%%%%%%%
            Overlap_tsALSI_PRet = table2array(BF_BH_TT(Window:t, 'JALSHTR_Index'));
            % 0 to start of series to match length of return series from backtest loop
            Overlap_tsALSI_PRet(1, :) = 0;
            Overlap_tsALBI_PRet = table2array(returns_data(Window:t, 'ALB_Index'));
            Overlap_tsALBI_PRet(1, :) = 0;
            Overlap_tsCash_PRet = table2array(returns_data(Window:t, 'Cash'));
            Overlap_tsCash_PRet(1, :) = 0;

            Benchmark_tsPRets = [Overlap_tsALSI_PRet,Overlap_tsALBI_PRet,Overlap_tsCash_PRet];
            backtestedPortfolios.Benchmark_PRets = Benchmark_tsPRets;

            %% 4. TRIM CONDITION NUMBERS:
            % Trim resulting to window
            cov_con_n = cov_con_n(Window:t,:);

            %% 5. Package WEIGHTS for OUTPUT:
            % Trim resulting to window & store in cell array %%%%%%%%%%%
            % NOTE: each set of optimal weights have x number of columns based on numb
            % assets. eg SR has 6 but BF have 3.

            %%% Adjust HRP if cash constraint is implemented:
            if backtestedPortfolios.CashConstraint ~=1
                % Downweight the equity controls to (1- CC)%
                Overlap_tsHRP_Wts = Overlap_tsHRP_Wts.*(1-backtestedPortfolios.CashConstraint);

                % Cash to add back based on CC 
                cashConstraint = backtestedPortfolios.CashConstraint * ones(size(Overlap_tsHRP_Wts, 1), 1);
                Overlap_tsHRP_Wts = [Overlap_tsHRP_Wts, cashConstraint];
               
            end

            % Initialize the cell array
            OptPortWts_cell = cell(2, 5);

            % Assign the vectors to each cell in the cell array
            % Have portfolio Type as separate arrays to identify cells
            OptPortWts_cell(1,:) =  backtestedPortfolios.PortfoliosList(1:5);
            OptPortWts_cell{2,1} = Overlap_tsEW_Wts(Window:t,:);
            OptPortWts_cell{2,2} = Overlap_tsSR_Wts(Window:t,:);
            OptPortWts_cell{2,3} = Overlap_tsBH_Wts0(Window:t,:);
            OptPortWts_cell{2,4} = Overlap_tsHRP_Wts(Window:t,:);
            OptPortWts_cell{2,5} = Overlap_tsCM_Wts(Window:t,:);

            backtestedPortfolios.OptPortWts = OptPortWts_cell;

            %% 6. Package RETURNS for OUTPUT:
            % Trim resulting to window & store in cell array %%%%%%%%%%%

            % Initialize the cell array
            Realised_tsPRet = cell(2, 8);


            % Assign the names to the first row of the cell array
            Realised_tsPRet(1,:) =  backtestedPortfolios.PortfoliosList ;
            Realised_tsPRet{2,1} = Overlap_tsEW_PRet(Window:t,:);
            Realised_tsPRet{2,2} = Overlap_tsSR_PRet(Window:t,:);
            Realised_tsPRet{2,3} = Overlap_tsBH_PRet(Window:t,:);
            Realised_tsPRet{2,4} = Overlap_tsHRP_PRet(Window:t,:);
            Realised_tsPRet{2,5} = Overlap_tsCM_PRet(Window:t,:);
            Realised_tsPRet{2,6} = Overlap_tsALSI_PRet;
            Realised_tsPRet{2,7} = Overlap_tsALBI_PRet;
            Realised_tsPRet{2,8} = Overlap_tsCash_PRet;

            %% 9. Create Timetable object to store realised returns in %%%%%%%%%%%
            % Contains the same as Realised_tsPRet, creating TT was a quick fix for
            % external problem, can be made more efficient at a later stage.
            backtestedPortfolios.Realised_tsPRet_TT = timetable(returns_data.Time(Window:t,:), ...
                Overlap_tsEW_PRet(Window:t,:), ...
                Overlap_tsSR_PRet(Window:t,:), ...
                Overlap_tsBH_PRet(Window:t,:), ...
                Overlap_tsHRP_PRet(Window:t,:), ...
                Overlap_tsCM_PRet(Window:t,:), ...
                Overlap_tsALSI_PRet,...
                Overlap_tsALBI_PRet,...
                Overlap_tsCash_PRet,...
                'VariableNames',{'EW (CM)', ...
                'MVSR max', ...
                'BalFund (BH)', ...
                'HRP', ...
                'BalFund (CM)',...
                'ALSI',...
                'ALBI',...
                'Cash'});

            % %% Annualised geometric excess returns for SR
            % From (Window + 1) to account for initial 0 return.
            backtestedPortfolios.ExcessReturns = SR_dif_t(Window+1:t,:);
            backtestedPortfolios.GeometricSR = geo_sr(backtestedPortfolios.ExcessReturns,12);

            %% 7. Backtest Portfolio SHARPE RATIOS %%%%%%%%%%%
            % Calculate the SR differential/excess return at each time step
            % ### 1. Equally Weighted (EW)###
            SR_Overall_EW = sqrt(12)*((mean(Overlap_tsEW_PRet(Window:t,:))- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsEW_PRet(Window:t,:)));
            % ### 2. SR Maximizing ###
            SR_Overall_MVSR = sqrt(12)*((mean(Overlap_tsSR_PRet(Window:t,:))- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsSR_PRet(Window:t,:)));
            % ### 3. Balanced Fund Buy-Hold ###
            SR_Overall_BH = sqrt(12)*((mean(Overlap_tsBH_PRet(Window:t,:))- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsBH_PRet(Window:t,:)));
            % ### 4. HRP ###
            SR_Overall_HRP = sqrt(12)*((mean(Overlap_tsHRP_PRet(Window:t,:))- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsHRP_PRet(Window:t,:)));
            % ### 5. Balanced Fund Constant Mix (CM) ###
            SR_Overall_CM = sqrt(12)*((mean(Overlap_tsCM_PRet(Window:t,:))- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsCM_PRet(Window:t,:)));
            % ### 6. ALSI - Equity Proxy ###
            SR_Overall_ALSI = sqrt(12)*((mean(Overlap_tsALSI_PRet)- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsALSI_PRet));
            % ### 7. ALBI - Bonds Proxy ###
            SR_Overall_ALBI = sqrt(12)*((mean(Overlap_tsALBI_PRet)- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsALBI_PRet));
            % ### 8. JIBA3M - Cash Proxy ###
            SR_Overall_Cash = sqrt(12)*((mean(Overlap_tsCash_PRet)- ...
                mean(returns_data.Cash(Window:t,:)))/std(Overlap_tsCash_PRet));


            %% 8. Portfolio PERFORMANCE: %%%%%%%%%%%
            %  1. Calculate Geometrically Compounded Returns
            %  2. Trim and store in cell array
            % Pre-allocate for 8 variables (EW, SR, BH, HRP, CM, ALSI, ALBI, Cash)
            Realised_tsPIndx = cell(2,8);
            Realised_tsPIndx(1,:) =  backtestedPortfolios.PortfoliosList ;

            % Define the list of port types and their corresponding names
            variables = {
                'EW', 'SR', 'BH', 'HRP', 'CM', 'ALSI', 'ALBI', 'Cash'
                };

            % Loop through the ports, calculate the indices, and store
            for i = 1:length(variables)
                % Calculate the decimal return and cumulative prod
                decimal_ret = eval(['Overlap_ts' variables{i} '_PRet(1:end,:) + 1']);
                PIndx = cumprod(decimal_ret);

                % Store the results in the cell array
                Realised_tsPIndx{2,i} = PIndx;
            end

            %% 9. Create Timetable object to store cumulative returns in %%%%%%%%%%%
            Rolling_portfolioSet = timetable(returns_data.Time(Window:t,:), ...
                Realised_tsPIndx{2,1}(Window:t,:), ...
                Realised_tsPIndx{2,2}(Window:t,:), ...
                Realised_tsPIndx{2,3}(Window:t,:), ...
                Realised_tsPIndx{2,4}(Window:t,:), ...
                Realised_tsPIndx{2,5}(Window:t,:), ...
                'VariableNames',{'EW (CM)', ...
                'MVSR max', ...
                'BalFund (BH)', ...
                'HRP', ...
                'BalFund (CM)'});
            %%% Adding in the additional benchmark series
            Rolling_portfolioSet=[Rolling_portfolioSet timetable(returns_data.Time(Window:t,:), ...
                Realised_tsPIndx{2,6},Realised_tsPIndx{2,7}, ...
                Realised_tsPIndx{2,8} , ...
                'VariableNames',{'ALSI', ...
                'ALBI', ...
                'Cash'})];

            backtestedPortfolios.RollingPerformance = Rolling_portfolioSet;

            %% Call attribution functions
            backtestedPortfolios = attribution(backtestedPortfolios);

            %% Call Max Drawdown Table functions
            if strcmp(backtestedPortfolios.MaxDD_cal, 'off')
                % do nothing
            else
               try
                backtestedPortfolios.MaxDrawDowns = maxDD(backtestedPortfolios);
               catch
                   backtestedPortfolios.MaxDrawDowns = [];
                   msg = 'An error occurred when calculating max drawdowns. Other functions may be impacted. Turn off to regain functionality.';
                   warning(msg)
               end
            end
            % %% 10. Create Timetable with SRs to store cumulative returns in %%%%%%%%%%%
            % Rolling_portfolioSet_SR = timetable(returns_data.Time(Window:t,:), ...
            %     Realised_tsPIndx{2,1}(Window:t,:), ...
            %     Realised_tsPIndx{2,2}(Window:t,:), ...
            %     Realised_tsPIndx{2,3}(Window:t,:), ...
            %     Realised_tsPIndx{2,4}(Window:t,:), ...
            %     Realised_tsPIndx{2,5}(Window:t,:), ...
            %     'VariableNames',{['EW (CM)  (SR = ' num2str(round(SR_Overall_EW,2)) ')'], ...
            %     ['MVSR max  (SR = ' num2str(round(SR_Overall_MVSR,2)) ')'], ...
            %     ['BalFund (BH)   (SR = ' num2str(round(SR_Overall_BH,2)) ')'], ...
            %     ['HRP   (SR = ' num2str(round(SR_Overall_HRP,2)) ')'], ...
            %     ['BalFund (CM)    (SR = ' num2str(round(SR_Overall_CM,2)) ')']});
            % %%% Adding in the additional benchmark series
            % Rolling_portfolioSet_SR=[Rolling_portfolioSet_SR timetable(returns_data.Time(Window:t,:), ...
            %     Realised_tsPIndx{2,6},Realised_tsPIndx{2,7}, ...
            %     Realised_tsPIndx{2,8} , ...
            %     'VariableNames',{['ALSI  (SR = ' num2str(round(SR_Overall_ALSI,2)) ')'], ...
            %     ['ALBI  (SR = ' num2str(round(SR_Overall_ALBI,2)) ')'], ...
            %     ['Cash (JIBA3M)  (SR = ' num2str(round(SR_Overall_Cash,2)) ')']})];
        end

        % 3. %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%% attribution Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function backtestedPortfolios = attribution(backtestedPortfolios)

            % Calls all sub functions below to create a structure
            % this currently set up to test cb_ensemble for backtest_moments.m function
            attributions_struct = struct('PortfolioNames',[],'AnnualisedRet', ...
                [], 'AnnualisedRisk',[],'SharpeRatio', [],'AnnualisedSR',[], ...
                'PSR' ,[], "MaxDD" ,[],'CVaR',[]);

            attributions_struct.PortfolioNames = string(backtestedPortfolios.PortfoliosList);
            attributions_struct.AnnualisedRet = annualRet(backtestedPortfolios);
            attributions_struct.AnnualisedRisk = annualRisk(backtestedPortfolios);
            attributions_struct.SharpeRatio = geometric_mthlySR(backtestedPortfolios);
            attributions_struct.AnnualisedSR = geometric_annualSR(backtestedPortfolios);
            %%% Add zeros for PSR for benchmarks
            all_PSR = [backtestPSR(backtestedPortfolios)',NaN,NaN,NaN];
            attributions_struct.PSR = all_PSR;
            %%% Add zeros for MaxDD for cash drawdown
            try
                if strcmp(backtestedPortfolios.MaxDD_cal,'on')
                    MaxDDtable = maxDD(backtestedPortfolios);
                    MaxDDvals =  MaxDDtable{:,1};
                    all_DDs = [MaxDDvals',0];
                    attributions_struct.MaxDD = all_DDs;
                else 
                   attributions_struct.MaxDD = ['-','-','-','-','-','-','-','-']; 
                end
            catch   
                attributions_struct.MaxDD = ['-','-','-','-','-','-','-','-'];
                msg = 'An error occurred when calculating max drawdowns. Other functions may be impacted. Turn off to regain functionality.';
                warning(msg)
            end
            % Extract fields from the structure
            AnnualisedRet = attributions_struct.AnnualisedRet(1:8);
            AnnualisedRisk = attributions_struct.AnnualisedRisk(1:8);
            SharpeRatio = attributions_struct.SharpeRatio(1:8);
            AnnualisedSR = attributions_struct.AnnualisedSR;
            PSR = attributions_struct.PSR(1:8);
            MaxDDvals = attributions_struct.MaxDD(1:8);

            % Extract fields from the structure
            % AnnualisedRet = attributions_struct.AnnualisedRet;
            % AnnualisedRisk = attributions_struct.AnnualisedRisk;
            % SharpeRatio = attributions_struct.SharpeRatio;
            % AnnualisedSR = attributions_struct.AnnualisedSR;
            % PSR = attributions_struct.PSR;

            % Create a table
            AttributionsTable = table(AnnualisedRet', AnnualisedRisk', ...
                SharpeRatio', AnnualisedSR', PSR',MaxDDvals', 'VariableNames', ...
                {'Ann.Return', 'Ann.Risk', 'SR','Ann.SR','PSR','Max.DD'}, ...
                'RowNames', {'EW', 'MV', 'BalFun (BH)','HRP', 'BalFun (CM)', 'ALSI','ALBI','Cash'});

            backtestedPortfolios.Attributions = AttributionsTable;
        end

        % 3.1.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%%    Annualised Return Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Changed to reflect percentage amounts
        function [AnnualisedRet] = annualRet(backtestedPortfolios)
            AnnualisedRet = 100*geo_ave(backtestedPortfolios.Realised_tsPRet_TT(2:end, :),12);
        end

        % 3.2.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%%    Annualised Risk Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [AnnualisedRisk] = annualRisk(backtestedPortfolios)
            AnnualisedRisk = zeros(1, width(backtestedPortfolios.Realised_tsPRet_TT));

            for port = 1:width(backtestedPortfolios.Realised_tsPRet_TT)
                RealisedRet = backtestedPortfolios.Realised_tsPRet_TT{:, port};
                AnnualisedRisk(port) = 100*(sqrt(12) * sqrt(var(RealisedRet)));
            end
        end

         % 3.3.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%%  Monthly Geometric SR Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function SharpeRatio = geometric_mthlySR(backtestedPortfolios)
            
            % benchmark_Attribution 
            ALSI_Excess = backtestedPortfolios.Benchmark_PRets(:,1)-backtestedPortfolios.Benchmark_PRets(:,3);
            ALSI_SR = geo_sr(ALSI_Excess,1);
            ALBI_Excess = backtestedPortfolios.Benchmark_PRets(:,2)-backtestedPortfolios.Benchmark_PRets(:,3);
            ALBI_SR = geo_sr(ALBI_Excess,1);
            Cash_SR = geo_sr(backtestedPortfolios.Benchmark_PRets(:,3),1);
            
            SharpeRatio = geo_sr(backtestedPortfolios.ExcessReturns,1);

            SharpeRatio = [SharpeRatio,ALSI_SR,ALBI_SR,Cash_SR];
        end

        % 3.4.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%%  Annualised Geometric SR Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AnnualisedSR = geometric_annualSR(backtestedPortfolios)
            AnnualisedSR = geo_sr(backtestedPortfolios.ExcessReturns,12);

            % benchmark_Attribution 
            ALSI_Excess = backtestedPortfolios.Benchmark_PRets(:,1)-backtestedPortfolios.Benchmark_PRets(:,3);
            ALSI_AnnSR = geo_sr(ALSI_Excess,12);
            ALBI_Excess = backtestedPortfolios.Benchmark_PRets(:,2)-backtestedPortfolios.Benchmark_PRets(:,3);
            ALBI_AnnSR = geo_sr(ALBI_Excess,12);
            Cash_AnnSR = geo_sr(backtestedPortfolios.Benchmark_PRets(:,3),12);
            
            AnnualisedSR = [AnnualisedSR,ALSI_AnnSR,ALBI_AnnSR,Cash_AnnSR];
        end

        % 3.5.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%%  PSR Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function PSR_ZeroBenchmark = backtestPSR(backtestedPortfolios)

            %%% For STRATEGY-Wise PSR
            if strcmp(backtestedPortfolios.PSRbenchmark, 'strategyWise')
                J = size(backtestedPortfolios.ExcessReturns,2);
                PSR_ZeroBenchmark = zeros(J,J);

                for strategy = 1:J
                    for bench_port = 1:J
                        PSR_ZeroBenchmark(strategy, bench_port) = psr(backtestedPortfolios.ExcessReturns(:, strategy), ...
                            backtestedPortfolios.Realised_tsPRet_TT{:, bench_port});
                    end
                end

                Portfolio_Names = string(strrep(backtestedPortfolios.PortfoliosList, '_', ' '));
                % Add variable names to the first row and first column of port_psr
                PSR_ZeroBenchmark = [Portfolio_Names; PSR_ZeroBenchmark];

                %%% For ZERO SKill (i.e. benchmark = 0) PSR
            elseif  strcmp(backtestedPortfolios.PSRbenchmark, 'zeroSkill')
                J = size(backtestedPortfolios.ExcessReturns,2);
                PSR_ZeroBenchmark = zeros(J,1);
                for strategy = 1:J
                    PSR_ZeroBenchmark(strategy) = psr(backtestedPortfolios.ExcessReturns(:, strategy), 0);

                end
            end
        end

        % 3.6.  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%%  Maximum Drawdown Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [MaxDDtable] = maxDD(backtestedPortfolios)
            performanceSeries = table2array(backtestedPortfolios.RollingPerformance);
            [MaxDD, MaxDDIndex] = maxdrawdown(performanceSeries);

            %%%% Extract START dates based on indices
            startDatesIdx = MaxDDIndex(1,:);
            if sum(isnan(startDatesIdx))== 0
                startDates = backtestedPortfolios.RollingPerformance.Time(startDatesIdx(1,:));
            % NB NOTE: this else statement is a specific work around of NaN handling
            % for this data specifically. It will need to be generalised to be
            % effective on alternative portfolios.
            else
                startDates = backtestedPortfolios.RollingPerformance.Time(MaxDDIndex(1,1:7));
            end
            %%%% Extract END dates based on indices
            endDatesIdx = MaxDDIndex(2,:);
            if sum(isnan(endDatesIdx))== 0
                endDates = backtestedPortfolios.RollingPerformance.Time(endDatesIdx(1,:));
            % NB NOTE: this else statement is a specific work around of NaN handling
            % for this data specifically. It will need to be generalised to be
            % effective on alternative portfolios.
            else
                endDates = backtestedPortfolios.RollingPerformance.Time(MaxDDIndex(1,1:7));
            end

            MaxDDtable = table(round(100*(MaxDD(1:7)'),4), endDates, startDates,'VariableNames', ...
                {'Max Drawdown', 'Start Date', 'End Date'}, ...
                'RowNames', {'EW', 'MV', 'BalFun (BH)','HRP', 'BalFun (CM)', 'ALSI','ALBI'});
        end
        % 4. %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% %%%%% Performance Plot Fn %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function backtest_plot_gcf = PerformancePlot(backtestedPortfolios)

            %%% Title based CC: 
            if backtestedPortfolios.CashConstraint ~= 1 && isempty(backtestedPortfolios.WinsorStd) && backtestedPortfolios.RegLambda == 0
                  CC_percent = (backtestedPortfolios.CashConstraint)*100;
                title_text = [num2str(CC_percent) '% Cash Constraint'  ...
                       ' Non-HSFP'];
            %%% Title based on WINSOR
            elseif backtestedPortfolios.CashConstraint == 1 && ~isempty(backtestedPortfolios.WinsorStd) && backtestedPortfolios.RegLambda == 0
             title_text = [num2str(backtestedPortfolios.WinsorStd) ' sd. Winsoried Non-HSFP'];

              %%% Title based on Reg
            elseif backtestedPortfolios.CashConstraint == 1 && isempty(backtestedPortfolios.WinsorStd) && backtestedPortfolios.RegLambda ~= 0
             title_text = ['Regularised \lambda = ' num2str(backtestedPortfolios.RegLambda) ' ' ...
                 'Non-HSFP'];

             %%% Title based on CC & W
            elseif backtestedPortfolios.CashConstraint ~= 1 && ~isempty(backtestedPortfolios.WinsorStd) && backtestedPortfolios.RegLambda == 0
                CC_percent = (backtestedPortfolios.CashConstraint)*100;
                title_text = [num2str(CC_percent) '% Cash Constraint & ' num2str(backtestedPortfolios.WinsorStd) ' sd. Winsorised ' ...
                 'Non-HSFP'];

             %%% Title based on CC & R
            elseif backtestedPortfolios.CashConstraint ~= 1 && isempty(backtestedPortfolios.WinsorStd) && backtestedPortfolios.RegLambda ~= 0
                CC_percent = (backtestedPortfolios.CashConstraint)*100;
                title_text = [num2str(CC_percent) ['% Cash Constraint ' ...
                    '& Regularised \lambda = '] num2str(backtestedPortfolios.RegLambda) ' ' ...
                 'Non-HSFP'];

             %%% Title based on W & R
            elseif backtestedPortfolios.CashConstraint == 1 && ~isempty(backtestedPortfolios.WinsorStd) && backtestedPortfolios.RegLambda ~= 0
             title_text = [num2str(backtestedPortfolios.WinsorStd) ' sd. Winsorised & Regularised (\lambda = ' num2str(backtestedPortfolios.RegLambda) ')' ...
                 ' Non-HSFP'];
            
             %%% Title based on W & R & CC
            elseif backtestedPortfolios.CashConstraint ~= 1 && ~isempty(backtestedPortfolios.WinsorStd) && backtestedPortfolios.RegLambda ~= 0
                CC_percent = (backtestedPortfolios.CashConstraint)*100;
                title_text = [num2str(CC_percent) '% Cash Constraint, ' ...
                    'Winsorised & Regularised ' ...
                 'Non-HSFP' ];

            else
              title_text = ['Non-HSFP Backtest: TRIs on ', ...
                num2str(backtestedPortfolios.WindowLength), ...
                ' Month Rolling Window'];
            end

            figure('InnerPosition', [100, 100, 600, 600]);

            colours = [[0, 0, 0.5];           % blue
                0.8500 0.3250 0.0980;  % orange
                0.9290 0.6940 0.1250;  % yellow,
                0.4940 0.1840 0.5560;  % purple
                0.4660 0.6740 0.1880;  % green
                0.3010 0.7450 0.9330;  % light blue
                0.6350 0.0780 0.1840;  % red
                0.9290 0.6940 0.6940]; % new color (light pink)

            numLines = size(backtestedPortfolios.RollingPerformance, 2);
            for i = 1:numLines
                lineColor = colours(mod(i-1, size(colours, 1))+1, :);
                plot(backtestedPortfolios.RollingPerformance.Time, ...
                    backtestedPortfolios.RollingPerformance{:, i}, ...
                    'LineWidth', 1.2, 'Color', lineColor);
                hold on;
            end

            ylabel('Price Index', 'FontSize', 15);
            xlabel('Time', 'FontSize', 15);
            title(title_text, 'FontSize', 16);
            legend(backtestedPortfolios.RollingPerformance.Properties.VariableNames, ...
                'Location', 'northwest', 'FontSize', 14);
            set(gca, 'FontSize', 12);
            backtest_plot_gcf = gcf;
            hold off;

            legend("Position", [0.17173,0.5673,0.36486,0.2424])

            legend("Position", [0.1896,0.58723,0.36979,0.2424])
        end


        function RollW_Wt_Surfaces_Plot = OptControlPlot(backtestedPortfolios,signal_name)

            f = figure;
            % Set Y axis for datetime object
            Y = backtestedPortfolios.RollingPerformance.Time;
            % Create fig
            % f1 = figure('OuterPosition', [100, 100, 600, 600]);
            if backtestedPortfolios.Method == "none"
            sgtitle([strcat('Simulation Weight Surfaces, HS-FP Method: ',' ',backtestedPortfolios.Method)], 'FontSize', 12);
            else
            sgtitle([strcat('Simulation Weight Surfaces, HS-FP Method: ',' ',backtestedPortfolios.Method,', signal = ',signal_name)], 'FontSize', 12);

            end    
            % plot grid
            numRows = 2;
            numCols = 3;

            % Colour palette: Hexadecimal Colour Codes
            colours = [0 0.4470 0.7410; % dark blue
                0.8500 0.3250 0.0980; % orange
                0.9290 0.6940 0.1250; % yellow
                0.4940 0.1840 0.5560; % purple
                0.3010 0.7450 0.9330]; % light blue


            % Colour palette: Hexadecimal Colour Codes
            BF_colours = [0.4660 0.6740 0.1880; % green
                0.3010 0.7450 0.9330; % light blue
                0 0.4470 0.7410]; % dark blue

            %%% 1. Performance Plot %%%%
            subplot(numRows, numCols, 1);
            axis square;
            perform_colours = [[0, 0, 0.5];           % blue
                0.8500 0.3250 0.0980;  % orange
                0.9290 0.6940 0.1250;  % yellow,
                0.4940 0.1840 0.5560;  % purple
                0.4660 0.6740 0.1880;  % green
                0.3010 0.7450 0.9330;  % light blue
                0.6350 0.0780 0.1840;  % red
                0.9290 0.6940 0.6940]; % new color (light pink)

            numLines = size(backtestedPortfolios.RollingPerformance, 2);
            for i = 1:numLines
                lineColor = perform_colours(mod(i-1, size(perform_colours, 1))+1, :);
                plot(backtestedPortfolios.RollingPerformance.Time, ...
                    backtestedPortfolios.RollingPerformance{:, i}, ...
                    'LineWidth', 1.2, 'Color', lineColor);
                hold on;
            end

            ylabel('Price Index', 'FontSize', 9);
            xlabel('Time', 'FontSize', 15);
            % ylim([0.9, 4.5])
            title('Non-HSFP: Portfolio Cummulative TRIs', 'FontSize', 9);
            legend(backtestedPortfolios.RollingPerformance.Properties.VariableNames, ...
                'Location', 'northwest', 'FontSize', 6);
            set(gca, 'FontSize', 9);

            %%% 2. Equally Weighted %%%%
            ax(1) = subplot(numRows, numCols, 2);
            grid on
            Z = [backtestedPortfolios.OptPortWts{2,1}];
            h = ribbon(Y,Z,0.5);
            colormap(ax(1),colours);
            for i = 1:numel(h)
                h(i).EdgeColor = colours(i,:);
            end
            xlabel('Asset Class')
            set(gca,'xtick',1:5,'xticklabel',{'ALBI','FINI15','INDI25','RESI20','Cash'});
            ylabel('Time')
            zlabel('Opt Weight')
            view([56.7207012835473 33.9084446444713]);
            title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,1} ...
                ' Portfolio Controls'],'FontSize', 9);


            %%% 3.  MV SR Max %%%%
            ax(2) = subplot(numRows, numCols, 3);
            Z = [backtestedPortfolios.OptPortWts{2,2}];
            grid on
            h1 = ribbon(Y,Z,0.5);
            colormap(ax(2),colours);
            for i = 1:numel(h1)
                h1(i).EdgeColor = colours(i,:);
            end
            xlabel('Asset Class')
            set(gca,'xtick',1:5,'xticklabel',{'ALBI','FINI15','INDI25','RESI20','Cash'});
            ylabel('Time')
            zlabel('Opt Weight')
            view([57.336 78.226])
            title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,2} ...
                ' Portfolio Controls'],'FontSize', 9);


            %%% 4. BF B-H %%%%
            ax(3) = subplot(numRows, numCols, 4);
            Z = [backtestedPortfolios.OptPortWts{2,3}];
            h2 = ribbon(Y,Z,0.5);
            colormap(ax(3),BF_colours);
            for i = 1:numel(h2)
                h2(i).EdgeColor = BF_colours(i,:);
            end
            xlabel('Asset Class')
            set(gca,'xtick',1:3,'xticklabel',{'ALSI', 'Cash','ALBI'});
            ylabel('Time')
            zlabel('Opt Weight')
            view([60.3745064177363 23.430953351469])
            title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,3} ...
                ' Portfolio Controls'],'FontSize', 9);

            %%% 5. HRP %%%%
            ax(4) = subplot(numRows, numCols, 5);
            Z = [backtestedPortfolios.OptPortWts{2,4}];
            h3 = ribbon(Y,Z,0.5);
            colormap(ax(4),colours);
            for i = 1:numel(h3)
                h3(i).EdgeColor = colours(i,:);
            end
            xlabel('Asset Class')
            set(gca,'xtick',1:5,'xticklabel',{'ALBI','FINI15','INDI25','RESI20','Cash'});
            ylabel('Time')
            zlabel('Opt Weight')
            view([61.2860583430572 42.5455046439628])
            title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,4} ...
                ' Portfolio Controls'],'FontSize', 9);

            %%% 6. BF CM %%%%
            ax(5) = subplot(numRows, numCols, 6);
            Z = [backtestedPortfolios.OptPortWts{2,5}];
            h4 = ribbon(Y,Z,0.5);
            colormap(ax(5),BF_colours);
            for i = 1:numel(h4)
                h4(i).EdgeColor = BF_colours(i,:);
            end
            xlabel('Asset Class')
            set(gca,'xtick',1:3,'xticklabel',{'ALSI', 'Cash','ALBI'});
            ylabel('Time')
            zlabel('Opt Weight')
            view([53.0820910151692 23.4309538458165])
            title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,5} ...
                ' Portfolio Controls'],'FontSize', 9);


            subplot(2,3,2)
            view([58.18 17.39])
            subplot(2,3,3)
            view([69.23 58.45])
            subplot(2,3,5)
            view([60.95 25.20])

            % Export the fig as a PDF
            RollW_Wt_Surfaces_Plot = f;
            hold off
        end


        %%%%%%%%%%%% Weight surfaces for MV and HRP only

        function MV_HRP_Surfaces_Plot = MV_HRP_OptControlPlot(backtestedPortfolios,signal_name)

            f = figure;
            % Set Y axis for datetime object
            Y = backtestedPortfolios.RollingPerformance.Time;
            % Create fig
            % f1 = figure('OuterPosition', [100, 100, 600, 600]);
            if backtestedPortfolios.Method == "none" ||backtestedPortfolios.Method == "rolling_w" ||backtestedPortfolios.Method == "exp_decay" 
            sgtitle([strcat('Simulation Weight Surfaces, HS-FP Method: ',' ',backtestedPortfolios.Method)], 'FontSize', 12);
            else
            sgtitle([strcat('Simulation Weight Surfaces, HS-FP Method: ',' ',backtestedPortfolios.Method,', signal = ',signal_name)], 'FontSize', 12);

            end    
            % plot grid
            numRows = 1;
            numCols = 3;

            % Colour palette: Hexadecimal Colour Codes
            colours = [0 0.4470 0.7410; % dark blue
                0.8500 0.3250 0.0980; % orange
                0.9290 0.6940 0.1250; % yellow
                0.4940 0.1840 0.5560; % purple
                0.3010 0.7450 0.9330]; % light blue


            % Colour palette: Hexadecimal Colour Codes
            BF_colours = [0.4660 0.6740 0.1880; % green
                0.3010 0.7450 0.9330; % light blue
                0 0.4470 0.7410]; % dark blue

            %%% 1. Performance Plot %%%%
            subplot(numRows, numCols, 1);
            axis square;
            perform_colours = [[0, 0, 0.5];           % blue
                0.8500 0.3250 0.0980;  % orange
                0.9290 0.6940 0.1250;  % yellow,
                0.4940 0.1840 0.5560;  % purple
                0.4660 0.6740 0.1880;  % green
                0.3010 0.7450 0.9330;  % light blue
                0.6350 0.0780 0.1840;  % red
                0.9290 0.6940 0.6940]; % new color (light pink)

            numLines = size(backtestedPortfolios.RollingPerformance, 2);
            for i = 1:numLines
                lineColor = perform_colours(mod(i-1, size(perform_colours, 1))+1, :);
                plot(backtestedPortfolios.RollingPerformance.Time, ...
                    backtestedPortfolios.RollingPerformance{:, i}, ...
                    'LineWidth', 1.2, 'Color', lineColor);
                hold on;
            end

            ylabel('Price Index', 'FontSize', 9);
            xlabel('Time', 'FontSize', 15);
            % ylim([0.9, 4.5])
            title('Non-HSFP: Portfolio Cummulative TRIs', 'FontSize', 9);
            legend(backtestedPortfolios.RollingPerformance.Properties.VariableNames, ...
                'Location', 'northwest', 'FontSize', 6);
            set(gca, 'FontSize', 9);

            % %%% 2. Equally Weighted %%%%
            % ax(1) = subplot(numRows, numCols, 2);
            % grid on
            % Z = [backtestedPortfolios.OptPortWts{2,1}];
            % h = ribbon(Y,Z,0.5);
            % colormap(ax(1),colours);
            % for i = 1:numel(h)
            %     h(i).EdgeColor = colours(i,:);
            % end
            % xlabel('Asset Class')
            % set(gca,'xtick',1:5,'xticklabel',{'ALBI','FINI15','INDI25','RESI20','Cash'});
            % ylabel('Time')
            % zlabel('Opt Weight')
            % view([56.7207012835473 33.9084446444713]);
            % title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,1} ...
            %     ' Portfolio Controls'],'FontSize', 9);


            %%% 3.  MV SR Max %%%%
            ax(1) = subplot(numRows, numCols, 2);
            Z = [backtestedPortfolios.OptPortWts{2,2}];
            grid on
            h1 = ribbon(Y,Z,0.5);
            colormap(ax(1),colours);
            for i = 1:numel(h1)
                h1(i).EdgeColor = colours(i,:);
            end
            xlabel('Asset Class')
            set(gca,'xtick',1:5,'xticklabel',{'ALBI','FINI15','INDI25','RESI20','Cash'});
            ylabel('Time')
            zlabel('Opt Weight')
            view([57.336 78.226])
            title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,2} ...
                ' Portfolio Controls'],'FontSize', 9);


            %%% 4. BF B-H %%%%
            % ax(3) = subplot(numRows, numCols, 4);
            % Z = [backtestedPortfolios.OptPortWts{2,3}];
            % h2 = ribbon(Y,Z,0.5);
            % colormap(ax(3),BF_colours);
            % for i = 1:numel(h2)
            %     h2(i).EdgeColor = BF_colours(i,:);
            % end
            % xlabel('Asset Class')
            % set(gca,'xtick',1:3,'xticklabel',{'ALSI', 'Cash','ALBI'});
            % ylabel('Time')
            % zlabel('Opt Weight')
            % view([60.3745064177363 23.430953351469])
            % title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,3} ...
            %     ' Portfolio Controls'],'FontSize', 9);

            %%% 5. HRP %%%%
            ax(2) = subplot(numRows, numCols, 3);
            Z = [backtestedPortfolios.OptPortWts{2,4}];
            h2 = ribbon(Y,Z,0.5);
            colormap(ax(2),colours);
            for i = 1:numel(h2)
                h2(i).EdgeColor = colours(i,:);
            end
            xlabel('Asset Class')
            set(gca,'xtick',1:5,'xticklabel',{'ALBI','FINI15','INDI25','RESI20','Cash'});
            ylabel('Time')
            zlabel('Opt Weight')
            view([61.2860583430572 42.5455046439628])
            title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,4} ...
                ' Portfolio Controls'],'FontSize', 9);

            % %%% 6. BF CM %%%%
            % ax(5) = subplot(numRows, numCols, 6);
            % Z = [backtestedPortfolios.OptPortWts{2,5}];
            % h4 = ribbon(Y,Z,0.5);
            % colormap(ax(5),BF_colours);
            % for i = 1:numel(h4)
            %     h4(i).EdgeColor = BF_colours(i,:);
            % end
            % xlabel('Asset Class')
            % set(gca,'xtick',1:3,'xticklabel',{'ALSI', 'Cash','ALBI'});
            % ylabel('Time')
            % zlabel('Opt Weight')
            % view([53.0820910151692 23.4309538458165])
            % title(['Non-HSFP: ' backtestedPortfolios.OptPortWts{1,5} ...
            %     ' Portfolio Controls'],'FontSize', 9);


            % subplot(2,3,2)
            % view([58.18 17.39])
            % subplot(2,3,3)
            % view([69.23 58.45])
            % subplot(2,3,5)
            % view([60.95 25.20])

            % Export the fig as a PDF
            MV_HRP_Surfaces_Plot = f;
            hold off
        end
    end
end

