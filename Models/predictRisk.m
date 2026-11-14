function risk = predictRisk(model, T)
% PREDICTRISK  Seizure risk score (0 to 1) for every window in a feature table.
%   risk = predictRisk(model, T)
% model comes from trainModel. T must contain the model's feature columns.
% Returns a column vector, one value per row of T.

    X = T{:, model.featureNames};
    X(~isfinite(X)) = 0;
    [~, score] = predict(model.mdl, X);
    risk = double(score(:, model.mdl.ClassNames == 1));
    risk = risk(:);
end
