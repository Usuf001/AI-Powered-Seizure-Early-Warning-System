function checkChannels()
% CHECKCHANNELS  Confirm the 18 agreed channels exist in every downloaded patient.
% Run once after downloading. Prints OK, or the channels that are missing.
    cfg = config();
    patients = [cfg.trainPatients, cfg.testPatients];
    for i = 1:numel(patients)
        d = dir(fullfile(cfg.rawDir, patients{i}, '*.edf'));
        if isempty(d), fprintf('%s: no EDF files found\n', patients{i}); continue, end
        bad = 0;
        for j = 1:numel(d)
            info = edfinfo(fullfile(d(j).folder, d(j).name));
            labels = string(info.SignalLabels);
            missing = {};
            for c = 1:numel(cfg.channelNames)
                w = cfg.channelNames{c};
                if ~any(labels == w) && ~any(startsWith(labels, string(w) + "-"))
                    missing{end+1} = w; %#ok<AGROW>
                end
            end
            if ~isempty(missing)
                bad = bad + 1;
                fprintf('%s %s is missing: %s\n', patients{i}, d(j).name, strjoin(missing, ', '));
            end
        end
        if bad == 0
            fprintf('%s: OK (%d files)\n', patients{i}, numel(d));
        end
    end
end
