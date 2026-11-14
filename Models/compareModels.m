function compareModels()
% COMPAREMODELS  Compare Random Forest and SVM with leave-one-patient-out testing.
% Prints the AUC for each held-out training patient and for all of them together.
% AUC 0.5 = guessing, 1.0 = perfect. Training patients only.

    cfg = config();
    methods = {'rf', 'svm'};
    for k = 1:numel(methods)
        fprintf('\n%s, leave-one-patient-out\n', upper(methods{k}));
        R = looPatientScores(cfg.trainPatients, methods{k});
        pats = unique(R.patientID, 'stable');
        for p = 1:numel(pats)
            r = R(R.patientID == pats(p), :);
            [~, ~, ~, auc] = perfcurve(r.label, r.risk, 1);
            fprintf('  held out %-6s AUC %.3f\n', pats(p), auc);
        end
        [~, ~, ~, aucAll] = perfcurve(R.label, R.risk, 1);
        fprintf('  all held-out windows: AUC %.3f\n', aucAll);
    end
end
