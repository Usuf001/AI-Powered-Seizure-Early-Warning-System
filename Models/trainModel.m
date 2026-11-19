function model = trainModel(Ttrain, method, normalize)
% TRAINMODEL  Train a seizure classifier on a feature table.
%   model = trainModel(Ttrain)               Random Forest (default)
%   model = trainModel(Ttrain, 'svm')        SVM baseline
%   model = trainModel(Ttrain, 'rf', true)   force per-patient normalisation on/off
%
% Ttrain is a feature table (see README 4.4) from TRAINING patients only.
% If normalisation is on (default: cfg.normalizeFeatures), every feature is
% rescaled within each patient first, and predictRisk does the same to new data.
% Returns a struct: model.type, model.mdl, model.featureNames, model.trainedOn,
% model.normalize. Use predictRisk(model, T) to get a 0-1 risk score per window.

    cfg = config();
    if nargin < 2 || isempty(method), method = 'rf'; end
    if nargin < 3 || isempty(normalize), normalize = cfg.normalizeFeatures; end
    if normalize, Ttrain = normalizeByPatient(Ttrain); end

    cols = featureColumns(Ttrain);
    X = Ttrain{:, cols};
    X(~isfinite(X)) = 0;
    y = double(Ttrain.label);

    switch lower(method)
        case 'rf'
            mdl = fitcensemble(X, y, 'Method', 'Bag', 'NumLearningCycles', 300, ...
                               'Learners', templateTree('MinLeafSize', 20), ...
                               'PredictorNames', cols, 'ClassNames', [0 1]);
        case 'svm'
            mdl = fitcsvm(X, y, 'Standardize', true, 'KernelFunction', 'rbf', ...
                          'KernelScale', 'auto', 'ClassNames', [0 1], ...
                          'PredictorNames', cols);
            mdl = fitPosterior(mdl);          % turns SVM scores into 0-1 probabilities
        otherwise
            error('Unknown method "%s". Use ''rf'' or ''svm''.', method);
    end

    model.type         = lower(method);
    model.mdl          = mdl;
    model.featureNames = cols;
    model.trainedOn    = unique(string(Ttrain.patientID))';
    model.normalize    = normalize;
end
