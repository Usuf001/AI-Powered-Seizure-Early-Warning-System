function downloadData(patients)
% DOWNLOADDATA  Download the CHB-MIT files this project needs.
%   downloadData()             all train and test patients from config.m
%   downloadData({'chb05'})    only the patients named
%
% For each patient it downloads the summary file, every file containing a
% seizure, and evenly spaced seizure-free files. Files go to cfg.rawDir.
% Safe to re-run: files that already exist are skipped, so a dropped
% connection just means running it again.

    cfg = config();
    if nargin < 1
        patients = [cfg.trainPatients, cfg.testPatients];
    end
    opts = weboptions('Timeout', 180);
    if ~isfolder(cfg.rawDir), mkdir(cfg.rawDir); end

    recsFile = websave(fullfile(tempdir, 'RECORDS'), [cfg.baseUrl 'RECORDS'], opts);
    seizFile = websave(fullfile(tempdir, 'RECORDS-WITH-SEIZURES'), ...
                       [cfg.baseUrl 'RECORDS-WITH-SEIZURES'], opts);
    allRecs  = strtrim(readlines(recsFile));  allRecs(allRecs == "")   = [];
    seizRecs = strtrim(readlines(seizFile));  seizRecs(seizRecs == "") = [];

    failed = strings(0, 1);
    for i = 1:numel(patients)
        p = string(patients{i});
        if ismember(char(p), cfg.excludePatients)
            warning('Skipping %s (excluded in config.m).', p); continue
        end
        nNormal = cfg.trainNormalFilesPerPatient;
        if ismember(char(p), cfg.testPatients)
            nNormal = cfg.testNormalFilesPerPatient;
        end

        pRecs   = allRecs(startsWith(allRecs, p + "/"));
        pSeiz   = seizRecs(startsWith(seizRecs, p + "/"));
        pNormal = setdiff(pRecs, pSeiz, 'stable');
        if numel(pNormal) > nNormal
            idx = unique(round(linspace(1, numel(pNormal), nNormal)));
            pNormal = pNormal(idx);   % evenly spaced across the recording
        end
        files = [p + "/" + p + "-summary.txt"; pSeiz(:); pNormal(:)];

        fprintf('\n%s: %d files (%d seizure, %d seizure-free)\n', ...
                p, numel(files), numel(pSeiz), numel(pNormal));
        for k = 1:numel(files)
            rel  = files(k);
            dest = fullfile(cfg.rawDir, strrep(rel, "/", filesep));
            if isfile(dest)
                fprintf('  [%d/%d] have %s\n', k, numel(files), rel); continue
            end
            destDir = fileparts(dest);
            if ~isfolder(destDir), mkdir(destDir); end
            ok = false;
            for attempt = 1:3
                try
                    tmp = dest + ".part";
                    websave(tmp, cfg.baseUrl + rel, opts);
                    movefile(tmp, dest);
                    ok = true; break
                catch ME
                    fprintf('  retry %d for %s (%s)\n', attempt, rel, ME.message);
                    pause(5);
                end
            end
            if ok
                fprintf('  [%d/%d] done %s\n', k, numel(files), rel);
            else
                failed(end+1, 1) = rel; %#ok<AGROW>
            end
        end
    end

    if isempty(failed)
        fprintf('\nAll downloads complete.\n');
    else
        fprintf('\n%d files failed. Re-run downloadData() to retry:\n', numel(failed));
        fprintf('  %s\n', failed);
    end
end
