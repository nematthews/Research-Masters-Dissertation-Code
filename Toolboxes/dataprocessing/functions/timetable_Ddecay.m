function [SIG_SMOOTHED_TT, test_z, test_mu] = timetable_Ddecay(data_TT, tau_f, tau_s)
% Uses Meucci's double exponential decay method (2010)
% (based on Holt's linear method) to smooth data
% to reduce noise. Follows on to standardising the data for comparative
% purposes.
% NOTE: If there are variables in the timetable with varying lengths the Fn
% uses the max history available for each variable to ensure preservation
% of information for the smoothing. Variables of different lengths are
% synchronised at the end and will retain the initial time range of
% 'data_TT'.
%
%% INPUTS:
% data = unscaled state variables data e.g. Volatility index, inflation etc.
% (type: timetable)
% tau_f = fast half-life at which decay volatilities
% (type: double)
% tau_s = slow half-life at which decay correlations
% (type: double)

% Author: Nina Matthews (2023)

% $Revision: 1.4 $ $Date: 2023/05/05 11:01:45 $ $Author: Nina Matthews $

%%
% Get the variable names from the timetable
varNames = data_TT.Properties.VariableNames;

% Initialize the double decay or Holt's linear forecasted values
try
    % Try creating SIG_SMOOTHED_TT using data_TT.Dates
    SIG_SMOOTHED_TT = timetable('RowTimes', data_TT.Dates);
catch
    % If an error occurs, create SIG_SMOOTHED_TT using data_TT.Time
    SIG_SMOOTHED_TT = timetable('RowTimes', data_TT.Time);
end


% Loop over each column/variable in the timetable
for i = 1:length(varNames)
    % Extract the data column
    sig_TT = data_TT(:, i);

    % Remove NaN rows but keep the date col so we can match it up using dates
    % later
    full_data = sig_TT;
    [~,idx] = max(sum(isnan(full_data{:,:}),1));
    rmmissingProxy =  full_data.Properties.VariableNames{idx};
    % cut timetable
    state_sig = rmmissing(full_data,"DataVariables",rmmissingProxy);

    % Using cut table
    T = height(state_sig);
    timestamp = 1:T;

    % row of 0s as storage for the z-scores
    z = zeros(1, T);

    % Apply 1st decay function using HS-FP exp decay probabilities
    for t = 1:T
        if isnan(state_sig{t, 1})
            z(t) = nan;
        else
            p_es_fast = exp(-log(2) / tau_f * (t - timestamp(1:t)));
            p_es_fast(p_es_fast==0)=10^-250;
            gamma_f = sum(p_es_fast);
            z(t) = sum(p_es_fast .* state_sig{1:t,1}') / gamma_f;
        end
        %%%%%% Can try to change the above to matrix notation later %%%%%%
        %         z = nan(T, 1);
        %         valid_indices = ~isnan(state_sig);
        %         p_es_fast = exp(-log(2) / tau_f * (1:T));
        %         p_es_fast(p_es_fast == 0) = 10^-250;
        %         gamma_f = cumsum(p_es_fast);
        %
        %         z(valid_indices) = cumsum(p_es_fast(valid_indices) .* state_sig(valid_indices)) ./ gamma_f(valid_indices)';

    end
    test_z = z;

    % Standardise: z-scoring
    mu_est = zeros(1, T);
    mu2_est = zeros(1, T);
    sd_est = zeros(1, T);

    for t = 1:T
        if isnan(state_sig{t, 1})
            z(t) = nan;
        else
            p_es_slow = exp(-log(2) / tau_s * (t - timestamp(1:t)));
            p_es_slow(p_es_slow==0)=10^-250;
            gamma_s = sum(p_es_slow);
            % Mecci's double decay calc for mu and Sig
            mu_est(t) = sum(p_es_slow .* z(1:t)) / gamma_s;
            mu2_est(t) = sum(p_es_slow .* z(1:t).^2) / gamma_s;
            sd_est(t) = sqrt(mu2_est(t) - (mu_est(t))^2);
        end
        test_mu = mu_est;
    end
    %%%%%% Can try to change the above to matrix notation later %%%%%%
    %     mu_est = zeros(1, T);
    %     mu2_est = zeros(1, T);
    %     sd_est = zeros(1, T);
    %     valid_indices = ~isnan(state_sig);
    %     p_es_slow = exp(-log(2) / tau_s * (1:T));
    %     p_es_slow(p_es_slow == 0) = 10^-250;
    %     gamma_s = cumsum(p_es_slow);
    %
    %     mu_est(valid_indices) = cumsum(p_es_slow(valid_indices) .* z(valid_indices)) ./ gamma_s(valid_indices);
    %     mu2_est(valid_indices) = cumsum(p_es_slow(valid_indices) .* z(valid_indices).^2) ./ gamma_s(valid_indices);
    %     sd_est(valid_indices) = sqrt(mu2_est(valid_indices) - mu_est(valid_indices).^2);
    %     test_mu = mu_est;


    % calc z-scores
    z = ((z - mu_est) ./ sd_est)';

    %% Store back into timetable object

    % Extract the dates from the 'state_sig' timetable
    dates = state_sig.Properties.RowTimes;

    % Create the new timetable using 'z' and the extracted dates
    z_score_TT = timetable(z, 'RowTimes', dates);
    % Synch with full data to retain the date range
    synch_TT = synchronize(full_data,z_score_TT);
    z_score_vec = synch_TT{:,2};

    %%

    % Store the forecasted values in the new timetable
    SIG_SMOOTHED_TT.(varNames{i}) = z_score_vec;

end

end


