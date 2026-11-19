function Tn = normalizeByPatient(T)
% NORMALIZEBYPATIENT  Robust z-score of every feature within each patient.
%   Tn = normalizeByPatient(T)
% For each patient, subtracts the median and divides by the interquartile range
% of each feature, using that patient's own windows. It needs NO labels, so it
% can be applied to a new patient's recording. This removes patient-to-patient
% differences in signal size and electrode quality, which otherwise make a model
% trained on some patients fail on another.
% Note: training patients are subsampled and test patients are not, so the
% median and spread differ slightly between them. Robust statistics keep that small.

    cols = featureColumns(T);
    Tn = T;
    pats = unique(string(T.patientID), 'stable');
    for p = 1:numel(pats)
        idx = string(T.patientID) == pats(p);
        X = T{idx, cols};
        med = median(X, 1, 'omitnan');
        sc = iqr(X);
        sc(~isfinite(sc) | sc < eps) = 1;
        Tn{idx, cols} = (X - med) ./ sc;
    end
end
