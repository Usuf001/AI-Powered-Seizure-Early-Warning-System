function risk = predictRisk(model, T)
% PREDICTRISK  Seizure risk score (0 to 1) for every window in a feature table.
%   risk = predictRisk(model, T)
% model comes from trainModel. T must contain the model's feature columns and
% the patientID column. If the model was trained with normalisation, T is
% rescaled within each patient first, so pass a patient's WHOLE feature table
% (not just a few of its windows). Returns a column vector, one value per row.

    if isfield(model, 'normalize') && model.normalize
        T = normalizeByPatient(T);
    end
    X = T{:, model.featureNames};
    X(~isfinite(X)) = 0;
    [~, score] = predict(model.mdl, X);
    risk = double(score(:, model.mdl.ClassNames == 1));
    risk = risk(:);
end
