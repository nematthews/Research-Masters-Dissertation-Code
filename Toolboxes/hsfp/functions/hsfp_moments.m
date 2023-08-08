function [hsfp_mu , hsfp_cov] = hsfp_moments(p,returns_TT)
% Calculates the first 2 moments of a return series using flexible
% probabilities.

% NOTE: Centring the scenarios results in scenarios have a mean of zero. 
% This step is NB as the covariance matrix is sensitive to the mean of the
% asset returns. If the scenarios are not centred, the covar would reflect 
% both variations in the scenarios themselves and the variations due to the
% mean of the scenarios. Centring allows to focus solely on the variations 
% within the scenarios, providing a more accurate representation of
% the relationships between assets.


%% INPUTS:
% p - flexible probability series (typically generated by entropy pooling
% approach, ensemble methods or time conditioned series).
% (Type: array [1 x T])

% returns_TT - table containing the historical return series for J assets
% (Type: TimeTable [T x J])

%%
if istimetable(returns_TT)
    returns_array = table2array(returns_TT);
end
% Mu
hsfp_mu = p * returns_array; 
% Centre scenarios to account for variation on mean
centered_array = returns_array - hsfp_mu; 
% Covar matrix
hsfp_cov = centered_array' * (centered_array .* p'); 
% any asymmetries in the matrix are corrected by averaging covar matrix 
% with its transpose.
 hsfp_cov = (hsfp_cov + hsfp_cov') / 2; 
end

