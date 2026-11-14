function R = looPatientScores(patientIDs, method)
% LOOPATIENTSCORES  Leave-one-patient-out risk scores for the training patients.
%   R = looPatientScores()                    all training patients, Random Forest
%   R = looPatientScores(patientIDs, 'svm')
%
% For each patient, trains on the OTHERS and scores the held-out patient, so
% every score comes from a model that never saw that patient. This is the honest
% way to compare models and to tune the alert threshold on training patients.
% Returns a table: patientID, fileName, windowStartSec, label, risk.

    cfg = config();
    rng(42);
    if nargin < 1 || isempty(patientIDs), patientIDs = cfg.trainPatients; end
    if nargin < 2 || isempty(method), method = 'rf'; end
    assert(~any(ismember(patientIDs, cfg.testPatients)), ...
        'Test patients must never be used here. Use training patients only.');

    T = cell(numel(patientIDs), 1);
    for i = 1:numel(patientIDs)
        S = load(fullfile(cfg.dataRoot, 'features', [patientIDs{i} '.mat']), 'T');
        T{i} = S.T;
    end

    keep = {'patientID', 'fileName', 'windowStartSec', 'label'};
    parts = cell(numel(T), 1);
    for i = 1:numel(T)
        others = setdiff(1:numel(T), i);
        model  = trainModel(vertcat(T{others}), method);
        risk   = predictRisk(model, T{i});
        parts{i} = [T{i}(:, keep), table(risk)];
        fprintf('  held out %s (%s): done\n', patientIDs{i}, method);
    end
    R = vertcat(parts{:});
end
