function model = trainModel(Ttrain, method)
% TRAINMODEL  Train a seizure classifier on a feature table.
%   model = trainModel(Ttrain)          Random Forest (default)
%   model = trainModel(Ttrain, 'svm')   SVM baseline
%
% Ttrain is a feature table (see README 4.4) from TRAINING patients only.
% Returns a struct: model.type, model.mdl, model.featureNames, model.trainedOn.
% Use predictRisk(model, T) to get a 0-1 risk score per window.

    if nargin < 2 || isempty(method), method = 'rf'; end
    cols = featureColumns(Ttrain);
    X = Ttrain{:, cols};
    X(~isfinite(X)) = 0;
    y = double(Ttrain.label);

    switch lower(method)
        case 'rf'
            mdl = fitcensemble(X, y, 'Method', 'Bag', 'NumLearningCycles', 200, ...
                               'Learners', templateTree('MinLeafSize', 5), ...
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
end
