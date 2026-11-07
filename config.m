function cfg = config()
% CONFIG  Single source of truth for every project setting (README section 4).
% Only the Project Lead edits this file. Never hard-code these values elsewhere.
% Put rng(42) at the top of your own scripts, not in here.

    % ---- Paths ----
    thisDir = fileparts(mfilename('fullpath'));
    cfg.projectRoot = thisDir;
    % Data lives outside Git. By default it is the repo's Data folder.
    % To point at a different location (for example a Google Drive folder),
    % set the ATLAS_DATA environment variable before running anything:
    %   setenv('ATLAS_DATA', 'G:\My Drive\TeamAtlas-Data')
    envRoot = getenv('ATLAS_DATA');
    if ~isempty(envRoot)
        cfg.dataRoot = envRoot;
    else
        cfg.dataRoot = fullfile(thisDir, 'Data');
    end
    cfg.rawDir       = fullfile(cfg.dataRoot, 'raw');
    cfg.processedDir = fullfile(cfg.dataRoot, 'processed');

    % ---- Patients ----
    cfg.trainPatients   = {'chb05', 'chb14', 'chb01', 'chb15'};
    cfg.testPatients    = {'chb03', 'chb18'};
    cfg.excludePatients = {'chb21'};   % same subject as chb01, never use

    % ---- Signal ----
    cfg.fs = 256;
    cfg.channelNames = {'FP1-F7','F7-T7','T7-P7','P7-O1', ...
                        'FP1-F3','F3-C3','C3-P3','P3-O1', ...
                        'FP2-F4','F4-C4','C4-P4','P4-O2', ...
                        'FP2-F8','F8-T8','T8-P8','P8-O2', ...
                        'FZ-CZ','CZ-PZ'};
    cfg.bandpassHz = [0.5 40];

    % ---- Windows and labels ----
    cfg.windowSec        = 5;
    cfg.overlap          = 0.5;
    cfg.windowSamples    = cfg.windowSec * cfg.fs;          % 1280
    cfg.stepSec          = cfg.windowSec * (1 - cfg.overlap); % 2.5
    cfg.labelOverlapMin  = 0.5;   % window is seizure if >= 50% overlaps a seizure

    % ---- Features ----
    cfg.bands = struct('delta',[0.5 4], 'theta',[4 8], 'alpha',[8 13], ...
                       'beta',[13 30], 'gamma',[30 40]);

    % ---- Alert rule ----
    cfg.alertConsecutiveWindows = 3;
    cfg.alertThreshold = [];      % tuned on training patients only, locked on day 11

    % ---- Training ----
    cfg.negativePerPositive = 10; % seizure-free windows kept per seizure window

    % ---- Download (CHB-MIT on PhysioNet) ----
    cfg.baseUrl = 'https://physionet.org/files/chbmit/1.0.0/';
    cfg.trainNormalFilesPerPatient = 6;
    cfg.testNormalFilesPerPatient  = 10;   % about 10 hours of seizure-free data
end
