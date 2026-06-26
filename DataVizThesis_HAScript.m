function DataVizThesis_HAScript(subject, run_list)

try

% MRI script for the HAshcraft DataViz Thesis

% subject = subject ID# | subject =  %fill the subjectID# |
% run_list = {1, 'FULL'} | first number is run, chronological (also will use the same block order), the second is list to use

% initial parameters
blockFixationTime = 12;
intertrialFixationTime = 0.5;
fixationTime = blockFixationTime;
mvnt_t = 4; % movement duration in seconds
qstn_t = 4; % question duration in seconds

%%
% input checks

    if nargin < 1 || isempty(subject)
        error("Provide subject (e.g., 'subject_n').");
    end
    
    if nargin < 2 || isempty(run_list)
        error("Provide run_list, e.g. {1, 'FULL'}.");
    end

    if iscell(run_list)
        b = run_list{1};
        listName = run_list{2};
    else
        b = run_list(1);
        listName = run_list(2);
    end

    b = double(b);
    listName = char(string(listName));
    
    if ~ismember(b, [1 2])
        error('First run_list value must be 1 or 2, e.g. {1, ''FULL''}.');
    end

subjID = char(string(subject));

    if startsWith(listName, 'stimList_')
        stimBase = listName;
    else
        stimBase = ['stimList_' listName];
    end

outFile = sprintf('%s_run%d.csv', subjID, b);
fontColor = [0 0 0];

% (hardcoded) blocks

    if b == 1
        orderMask = 'XMMMMMXQQQQQXMMMMMXQQQQQXMMMMMXQQQQQX';
    elseif b == 2
        orderMask = 'XQQQQQXMMMMMXQQQQQXMMMMMXQQQQQXMMMMMX';
    else
        sca;
        error('Block configuration not preset');
    end

condMask = orderMask(:);
N = length(condMask);

%%
% run_list (should be a .csv)
listFile = fullfile(pwd, [stimBase '.csv']);

    if ~exist(listFile, 'file')
        sca;
        error('CSV not found: %s', listFile);
    end

T = readtable(listFile, 'FileType', 'text', 'VariableNamingRule', 'preserve');
requiredColumns = ["stim_fn", "question", "answer_choice_1", "answer_choice_2"];
missingColumns = requiredColumns(~ismember(requiredColumns, string(T.Properties.VariableNames)));

    if ~isempty(missingColumns)
        sca;
        error('CSV is missing required column(s): %s', strjoin(missingColumns, ', '));
    end

T.stim_fn = string(T.stim_fn);
T.question = string(T.question);
T.answer_choice_1 = string(T.answer_choice_1);
T.answer_choice_2 = string(T.answer_choice_2);

    if height(T) < 1
        sca;
        error('CSV has no stimulus rows.');
    end

% .csv to trial assignment - motion is assigned randomly through a (psuedo)randomly (limited to 3 consequitve same directions) binary-vector (0 = Left, 1 = Right)
stimTrialIdx = find(condMask == 'M' | condMask == 'Q');
motionTrialIdx = find(condMask == 'M');
questionTrialIdx = find(condMask == 'Q');
nStimTrials = numel(stimTrialIdx);
nMotionTrials = numel(motionTrialIdx);
nQuestionTrials = numel(questionTrialIdx);
trialStimRow = nan(N, 1);

% can remove this; checks if M blocks = Q blocks
    if nQuestionTrials ~= nMotionTrials
        sca;
        error('Number of question trials must match number of movement trials.');
    end

    if height(T) < nMotionTrials
        sca;
        error('CSV must contain at least as many stimulus rows as movement trials.');
    end

stimRows = randperm(height(T), nMotionTrials).';
motionStimRows = stimRows(randperm(nMotionTrials));
questionStimRows = nan(nQuestionTrials, 1);
motionBlockNum = cumsum(condMask == 'X');
questionBlockNum = motionBlockNum;
motionBlockLabels = motionBlockNum(motionTrialIdx);
questionBlockLabels = questionBlockNum(questionTrialIdx);
motionBlocks = unique(motionBlockLabels, 'stable');
questionBlocks = unique(questionBlockLabels, 'stable');
pairedQuestionBlocks = nan(length(motionBlocks), 1);
pairFound = false;

    for pairTry = 1:1000
        candidateQuestionBlocks = questionBlocks(randperm(length(questionBlocks)));
        badPair = false;

        for i = 1:length(motionBlocks)

            if abs(motionBlocks(i) - candidateQuestionBlocks(i)) <= 1
                badPair = true;
                break;
            end
        end

        if ~badPair
            pairedQuestionBlocks = candidateQuestionBlocks;
            pairFound = true;
            break;
        end
    end

    if ~pairFound
        pairedQuestionBlocks = questionBlocks(randperm(length(questionBlocks)));
    end

    for i = 1:length(motionBlocks)
        thisMotionBlock = find(motionBlockLabels == motionBlocks(i));
        thisQuestionBlock = find(questionBlockLabels == pairedQuestionBlocks(i));

        if length(thisMotionBlock) ~= length(thisQuestionBlock)
            sca;
            error('Paired movement and question blocks must contain same number of trials');
        end

        blockStimRows = motionStimRows(thisMotionBlock);
        questionStimRows(thisQuestionBlock) = blockStimRows(randperm(length(blockStimRows)));
    end

    for i = 1:nMotionTrials
        trialStimRow(motionTrialIdx(i)) = motionStimRows(i);
        trialStimRow(questionTrialIdx(i)) = questionStimRows(i);
    end

% motion trail assignment; (psuedo)random (limited to 3 consequitve same directions) binary-vector (0 = Left, 1 = Right) generation
motionVec = zeros(nMotionTrials, 1);

    for i = 1:nMotionTrials
    
        if i >= 4 && motionVec(i-1) == motionVec(i-2) && motionVec(i-2) == motionVec(i-3)
            motionVec(i) = 1 - motionVec(i-1);
        else
            motionVec(i) = randi([0 1]);
        end
    end
    
    trialMotionVec = nan(N, 1);
    
    for i = 1:nMotionTrials
        trialMotionVec(motionTrialIdx(i)) = motionVec(i);
    end

%%
% PTB setup
KbName('UnifyKeyNames');
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 1);
scr = max(Screen('Screens'));
white = WhiteIndex(scr);
[win, rect] = PsychImaging('OpenWindow', scr, white);
[sw, sh] = Screen('WindowSize', win);
[cx, cy] = RectCenter(rect);
Screen('TextSize', win, 80);
Screen('TextFont', win, 'Times New Roman');

%%
% image preload
stimDir = fullfile(pwd, stimBase);
addpath(stimDir);

    if ~exist(stimDir, 'dir')
        sca;
        error('Stimulus folder not found: %s', stimDir);
    end

usedRows = trialStimRow(trialStimRow > 0);
usedNames = unique(strtrim(T.stim_fn(usedRows)));
texMap = containers.Map;

    for i = 1:length(usedNames)
        name = char(usedNames(i));
        imgPath = fullfile(stimDir, name);

        if ~exist(imgPath, 'file')
            sca;
            error('Unable to find image file for stimulus "%s" in %s', name, stimDir);
        end

        imgData = imread(imgPath);
        texMap(name) = Screen('MakeTexture', win, imgData);
    end

%%
% fMRI trigger setup
TRIGGER_UTIL_DIR = [pwd filesep 'TOOL_Matlab_trigger_utils'];
addpath(TRIGGER_UTIL_DIR);

% wait for scanner
instructions = 'Waiting for scanner...';
Screen('FillRect', win, white);
DrawFormattedText(win, instructions, 'center', 'center', fontColor);
Screen('Flip', win);
run_start_time = wait_for_trigger_kbqueue_all_dvc();

%%
% output setup
Trial = (1:N).';
BlockLab = strings(N, 1);
TrialCode = strings(N, 1);
StimulusName = strings(N, 1);
Response = nan(N, 1);
RT = nan(N, 1);
CorrectAns = nan(N, 1);
Correct = nan(N, 1);
fid = fopen(outFile, 'w');

    if fid == -1
        sca;
        error('Could not open output file: %s', outFile);
    end

fprintf(fid, 'Trial,TrialCode,Stimulus,Response,RT,CorrectAns,Correct\n');
fclose(fid);
fid = fopen(outFile, 'a');

%%
% trial loop

for t = 1:N
    trialCode = condMask(t);
    TrialCode(t) = string(trialCode);

    % fixation

    if trialCode == 'X'
        Screen('FillRect', win, white);
        DrawFormattedText(win, '+', 'center', 'center', fontColor);
        flipTime = Screen('Flip', win);
        fixStart = GetSecs;

        while GetSecs - fixStart < fixationTime
            [kd, ~, kc] = KbCheck;

                if kd

                    if kc(KbName('ESCAPE'))
                        sca;
                        error('escaped loop');
                    end
                end
        end

        BlockLab(t) = "FIXATION";
        StimulusName(t) = "";
        Response(t) = NaN;
        RT(t) = NaN;
        CorrectAns(t) = NaN;
        Correct(t) = 0;
        fprintf(fid, '%d,%s,%s,%s,%s,%s,%.0f\n',Trial(t), TrialCode(t),'', '', '', '', Correct(t));
        fclose(fid);
        fid = fopen(outFile, 'a');

        continue;
    end

    pressed = false;
    respKey = NaN;
    rt = NaN;

    %%
    % Questions blocks

    if trialCode == 'Q'
        BlockLab(t) = "QUESTION";
        stimRow = trialStimRow(t);
        stimName = strtrim(T.stim_fn(stimRow));
        questionText = strtrim(T.question(stimRow));
        answerOne = strtrim(T.answer_choice_1(stimRow));
        answerTwo = strtrim(T.answer_choice_2(stimRow));
        StimulusName(t) = stimName;
        texStim = texMap(char(stimName));
        srcRect = Screen('Rect', texStim);

        % image size
        srcW = srcRect(3) - srcRect(1);
        srcH = srcRect(4) - srcRect(2);
        maxImageW = sw * 0.85;
        maxImageH = sh * 0.42;
        imgScale = min(maxImageW / srcW, maxImageH / srcH);
        img_w = round(srcW * imgScale);
        img_h = round(srcH * imgScale);
        baseRect = [0 0 img_w img_h];

        correctAnswer = NaN;
        imageCenterY = round((sh * .05) + (img_h / 2));
        questionY = round(sh * .62);
        answerY = round(sh * .76);
        dstRect = CenterRectOnPointd(baseRect, cx, imageCenterY);
        leftAnswerRect = [0 answerY - 60 sw / 2 answerY + 120];
        rightAnswerRect = [sw / 2 answerY - 60 sw answerY + 120];
        Screen('FillRect', win, white);
        Screen('DrawTexture', win, texStim, [], dstRect, [], 1);
        DrawFormattedText(win, char(questionText), 'center', questionY, fontColor, 80);
        DrawFormattedText(win, ['1 = ' char(answerOne)], 'center', 'center', fontColor, [], [], [], [], [], leftAnswerRect);
        DrawFormattedText(win, ['2 = ' char(answerTwo)], 'center', 'center', fontColor, [], [], [], [], [], rightAnswerRect);
        flipTime = Screen('Flip', win);
        trialStart = GetSecs;

        while GetSecs - trialStart < qstn_t
            [kd, ~, kc] = KbCheck;

                if kd
    
                    if kc(KbName('ESCAPE'))
                        sca;
                        error('escaped loop');
                    end
    
                    if ~pressed
    
                        if kc(KbName('1!')) || kc(KbName('1'))
                            respKey = 1;
                            pressed = true;
                            rt = GetSecs - flipTime;
                        elseif kc(KbName('2@')) || kc(KbName('2'))
                            respKey = 2;
                            pressed = true;
                            rt = GetSecs - flipTime;
                        end
                    end
                end
        end

    %%
    % movement blocks

    elseif trialCode == 'M'
        BlockLab(t) = "MOVEMENT";
        stimRow = trialStimRow(t);
        stimName = strtrim(T.stim_fn(stimRow));
        StimulusName(t) = stimName;
        texStim = texMap(char(stimName));
        srcRect = Screen('Rect', texStim);

        % image size
        srcW = srcRect(3) - srcRect(1);
        srcH = srcRect(4) - srcRect(2);
        maxImageW = sw * 0.80;
        maxImageH = sh * 0.80;
        imgScale = min(maxImageW / srcW, maxImageH / srcH);
        img_w = round(srcW * imgScale);
        img_h = round(srcH * imgScale);
        baseRect = [0 0 img_w img_h];
        motionCode = trialMotionVec(t);

        if motionCode == 0
            correctAnswer = 1;
            directionSign = -1;
        elseif motionCode == 1
            correctAnswer = 2;
            directionSign = 1;
        else
            sca;
            error();
        end

        % movement
        totalTravelPixels = sw * 0.003; % movement speed
        startX = cx - directionSign * totalTravelPixels / 2;
        endX = cx + directionSign * totalTravelPixels / 2;
        firstFlip = NaN;

        while isnan(firstFlip) || GetSecs - firstFlip < mvnt_t

                if isnan(firstFlip)
                    elapsed = 0;
                else
                    elapsed = GetSecs - firstFlip;
                end

            proportion = min(elapsed / mvnt_t, 1);
            stimX = startX + proportion * (endX - startX);
            dstRect = CenterRectOnPointd(baseRect, stimX, cy);
            Screen('FillRect', win, white);
            Screen('DrawTexture', win, texStim, [], dstRect, [], 1);
            currentFlip = Screen('Flip', win);

                if isnan(firstFlip)
                    firstFlip = currentFlip;
                end

            [kd, ~, kc] = KbCheck;

                if kd
    
                    if kc(KbName('ESCAPE'))
                        sca;
                        error('escaped loop');
                    end
    
                    if ~pressed
    
                        if kc(KbName('1!')) || kc(KbName('1'))
                            respKey = 1;
                            pressed = true;
                            rt = GetSecs - firstFlip;
                        elseif kc(KbName('2@')) || kc(KbName('2'))
                            respKey = 2;
                            pressed = true;
                            rt = GetSecs - firstFlip;
                        end
                    end
                end
        end

        flipTime = firstFlip;
    else
        sca;
        error('Unknown trial block: %s', trialCode);
    end

    %%
    % intertrial fixation 
    Screen('FillRect', win, white);
    DrawFormattedText(win, '+', 'center', 'center', fontColor);
    Screen('Flip', win);
    lateStart = GetSecs;

    while GetSecs - lateStart < intertrialFixationTime
        [kd, ~, kc] = KbCheck;

            if kd
    
                if kc(KbName('ESCAPE'))
                    sca;
                    error('escaped loop');
                end
    
                if ~pressed
    
                    if kc(KbName('1!')) || kc(KbName('1'))
                        respKey = 1;
                        pressed = true;
                        rt = GetSecs - flipTime;
                    elseif kc(KbName('2@')) || kc(KbName('2'))
                        respKey = 2;
                        pressed = true;
                        rt = GetSecs - flipTime;
                    end
                end
            end
    end

    %%
    % save response
    Response(t) = respKey;
    RT(t) = rt;
    CorrectAns(t) = correctAnswer;
    Correct(t) = double(~isnan(respKey) && respKey == correctAnswer);

        if trialCode == 'Q'
            Correct(t) = NaN; % this is here for now, will update once correct answers are added to the .csv
        end

        if isnan(Response(t))
            respStr = "";
        else
            respStr = sprintf('%.0f', Response(t));
        end
    
        if isnan(RT(t))
            rtStr = "";
        else
            rtStr = sprintf('%.6f', RT(t));
        end

    stimOut = strrep(char(StimulusName(t)), '"', '""');
    fprintf(fid, '%d,%s,"%s",%s,%s,%.0f,%.0f\n',Trial(t), TrialCode(t),stimOut, respStr, rtStr, CorrectAns(t), Correct(t));
    fclose(fid);
    fid = fopen(outFile, 'a');
end

%%
% data collection/accuracy summary
movementTrials = condMask == 'M';
questionTrials = condMask == 'Q';
movementAcc = 100 * mean(Correct(movementTrials), 'omitnan');
questionResp = 100 * mean(~isnan(Response(questionTrials)), 'omitnan');
fprintf(fid, '\nMovement Accuracy,%.1f%%\n', movementAcc);
fprintf(fid, '\nQuestion Response Rate,%.1f%%\n', questionResp);
fclose(fid);

%%
% close PTB

    if exist('texMap', 'var')
        texKeys = keys(texMap);
    
        for i = 1:length(texKeys)
            Screen('Close', texMap(texKeys{i}));
        end
    end

sca;

catch ME
    sca;
    ListenChar(0);

    if exist('fid', 'var') && fid > 0

        try
            fclose(fid);
        catch
        end
    end

    rethrow(ME);

end
end