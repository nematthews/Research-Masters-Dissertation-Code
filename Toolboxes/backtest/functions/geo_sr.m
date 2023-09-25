function [geo_SR] = geo_sr(SR_dif_t, f)
% Calculate the Sharpe Ratio based off geometric averages of the risky
% asset and a risk free asset given realised returns of the risky and risk
% less.
%
%% INPUT:
% SR_dif_t - series of differencial/excess realised returns of an asset or portfolio
% (type: array double, [T x 1] | timetable object)
%
% NOTE: SR_dif_t can be a series of an asset returns, in this case the
% exces return used benchmark return as 0 as measure of comparing against
% no investment skill.
%
% f - (Optional) number of periods within a yr (e.g 12 for monthly, 
% 4 for quarterly) only used to calculate geo_average (i.e annualises mean
% returns NOT the SR.
% (type: double) NOTE: default = 1 i.e not annualised returns
% Author: Nina Matthews (2023)

% $Revision: 1.2 $ $Date: 2023/09/20 10:46:01 $ $Author: Nina Matthews $


if istimetable(SR_dif_t)
    SR_dif_t = table2array(SR_dif_t);
end

% Number of periods within a year (e.g., 12 for monthly) DEFUALT HERE f = 1

if nargin < 2
    f = 1;
end

%% Geometric differencial/excess returns for SR
% We use geometric average here as we are not using SR for prediction and
% decision making. We using historical realised excess returns to
% calculate an indicative measure of historical performance.

geo_SR = zeros(1,width(SR_dif_t));
ExcessRet_sd = zeros(1,width(SR_dif_t));

for i = 1:width(SR_dif_t)
    % Calculate Geometic Average of Excess Returns (to annualise f =12)
    geo_ExcessRet_ave = geo_ave(SR_dif_t(:,i),f);
    % Calc sd (under the assumption of normality)
    ExcessRet_sd(i) = std(SR_dif_t(:,i),1);

    %% Calcuate SRatio
    geo_SR(i) = geo_ExcessRet_ave/ExcessRet_sd(i);
end
end






