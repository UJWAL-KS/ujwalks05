function advanced_speech_analyzer()
    % ADVANCED REAL-TIME SPEECH ANALYZER
    % Only works with real microphone input - no simulation
    
    % Initialize app structure
    app = struct();
    
    % Create main figure
    app.fig = figure('Name', 'Advanced Speech Analyzer - Real Time (Microphone Only)', ...
                'NumberTitle', 'off', ...
                'Position', [50 50 1600 1000], ...
                'CloseRequestFcn', @close_app);
    
    try
        % Initialize audio system
        initialize_audio();
        
        % Create GUI components
        create_gui_components();
        
        % Initialize data structures
        initialize_data();
        
        % Start main processing loop
        start_analysis();
        
    catch ME
        fprintf('Initialization error: %s\n', ME.message);
        cleanup();
        rethrow(ME);
    end
    
    %% Nested Functions
    
    function initialize_audio()
        % Audio parameters
        app.fs = 22050;
        app.frameSize = 1024;
        app.audioInitialized = false;
        
        % Try to initialize real audio input
        try
            info = audiodevinfo;
            if ~isempty(info.input)
                app.audioInitialized = true;
                fprintf('Real audio input available!\n');
                
                % Initialize recorder with proper settings
                app.recorder = audiorecorder(app.fs, 16, 1);
                fprintf('Audio recorder initialized successfully.\n');
            else
                fprintf('No audio input devices found.\n');
                error('No microphone detected. Please connect a microphone and restart.');
            end
        catch ME
            fprintf('Audio initialization error: %s\n', ME.message);
            app.audioInitialized = false;
            error('Cannot initialize microphone. Please check your audio settings.');
        end
        
        fprintf('Sample Rate: %d Hz, Frame Size: %d\n', app.fs, app.frameSize);
        
        % Recording variables
        app.isRecording = false;
        app.recordedAudio = [];
        app.recordingStartTime = 0;
        app.maxRecordingSamples = 30 * app.fs; % 30 seconds max
    end

    function create_gui_components()
        % Create tab group
        app.tabGroup = uitabgroup(app.fig, 'Position', [0.02 0.02 0.96 0.96]);
        
        % Tab 1: Real-time Analysis
        create_realtime_tab();
        
        % Tab 2: Recording & Playback
        create_recording_tab();
        
        % Tab 3: Voice Analysis
        create_voice_tab();
        
        % Tab 4: Music Analysis
        create_music_tab();
        
        % Add status display only (removed overlapping controls)
        create_status_display();
    end

    function create_status_display()
        % Status indicator only - removed overlapping controls
        app.statusText = uicontrol('Style', 'text', ...
            'String', 'SPEAK INTO MICROPHONE TO START ANALYSIS', ...
            'Position', [1200 920 350 40], 'FontSize', 14, ...
            'BackgroundColor', [1 0.8 0.8], ...
            'ForegroundColor', 'red', 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');
        
        % Audio level meter
        app.levelMeter = uicontrol('Style', 'text', ...
            'String', '|----------| NO SIGNAL', ...
            'Position', [1200 880 250 25], 'FontSize', 12, ...
            'BackgroundColor', [0.2 0.2 0.2], ...
            'ForegroundColor', [1 0 0], 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');
        
        % Instructions
        instructionText = {
            'INSTRUCTIONS:', ...
            '1. Speak or sing into microphone', ...
            '2. Graphs will update only when', ...
            '   sound is detected', ...
            '3. No simulation - real input only'
        };
        
        uicontrol('Style', 'text', 'String', instructionText, ...
            'Position', [1200 800 250 80], 'FontSize', 10, ...
            'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
            'ForegroundColor', [0 0 0.5], 'FontWeight', 'bold');
    end

    function create_realtime_tab()
        tab1 = uitab(app.tabGroup, 'Title', 'Real-time Analysis');
        
        % Waveform display
        ax1 = subplot(3,3,1, 'Parent', tab1);
        app.waveformPlot = plot(ax1, zeros(app.frameSize,1));
        title(ax1, 'Audio Waveform - Speak to See Signal');
        xlabel(ax1, 'Samples'); ylabel(ax1, 'Amplitude');
        grid(ax1, 'on');
        ylim(ax1, [-1 1]);
        
        % Spectrum display
        ax2 = subplot(3,3,2, 'Parent', tab1);
        app.spectrumPlot = plot(ax2, zeros(512,1));
        title(ax2, 'Frequency Spectrum - Speak to See Spectrum');
        xlabel(ax2, 'Frequency (Hz)'); ylabel(ax2, 'Magnitude (dB)');
        grid(ax2, 'on');
        xlim(ax2, [0, min(8000, app.fs/2)]);
        ylim(ax2, [-80 0]);
        
        % Pitch history
        ax3 = subplot(3,3,3, 'Parent', tab1);
        app.pitchPlot = plot(ax3, nan(200,1), 'b-', 'LineWidth', 2);
        title(ax3, 'Pitch Contour (Hz) - Speak to See Pitch');
        xlabel(ax3, 'Time (frames)'); ylabel(ax3, 'Pitch (Hz)');
        grid(ax3, 'on');
        ylim(ax3, [50 500]);
        
        % Volume history
        ax4 = subplot(3,3,4, 'Parent', tab1);
        app.volumePlot = plot(ax4, nan(200,1), 'r-', 'LineWidth', 2);
        title(ax4, 'Volume Level - Speak to See Volume');
        xlabel(ax4, 'Time (frames)'); ylabel(ax4, 'Volume (RMS)');
        grid(ax4, 'on');
        ylim(ax4, [0 0.2]);
        
        % Spectrogram
        ax5 = subplot(3,3,[5,6], 'Parent', tab1);
        app.spectrogram = imagesc(ax5, zeros(128,200));
        title(ax5, 'Real-time Spectrogram - Speak to See Spectrogram');
        xlabel(ax5, 'Time'); ylabel(ax5, 'Frequency');
        colormap(ax5, 'jet');
        colorbar(ax5);
        
        % Voice activity and note display
        ax6 = subplot(3,3,7, 'Parent', tab1);
        app.vadIndicator = fill(ax6, [0 1 1 0], [0 0 1 1], [1 0 0]);
        title(ax6, 'Voice Activity');
        set(ax6, 'XTick', [], 'YTick', []);
        text(ax6, 0.5, -0.3, 'RED = No Voice\nGREEN = Voice Detected', ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
        
        ax7 = subplot(3,3,8, 'Parent', tab1);
        app.noteText = text(ax7, 0.5, 0.5, '--', ...
            'FontSize', 20, 'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', 'VerticalAlignment', 'middle');
        title(ax7, 'Musical Note');
        set(ax7, 'XTick', [], 'YTick', []);
        
        % Statistics panel
        ax8 = subplot(3,3,9, 'Parent', tab1);
        axis(ax8, 'off');
        app.statsText = text(ax8, 0.05, 0.95, {'MICROPHONE MODE', '===============', 'Status: Waiting for input...', 'No audio detected', 'Speak into microphone'}, ...
            'FontSize', 10, 'VerticalAlignment', 'top', ...
            'FontName', 'FixedWidth', 'Interpreter', 'none', ...
            'Color', [0.5 0.5 0.5]);
    end

    function create_recording_tab()
        tab2 = uitab(app.tabGroup, 'Title', 'Recording & Export');
        
        % Recording controls
        uicontrol(tab2, 'Style', 'pushbutton', ...
            'String', 'Start Recording', ...
            'Position', [50 900 150 40], ...
            'FontSize', 12, ...
            'Callback', @start_recording);
        
        uicontrol(tab2, 'Style', 'pushbutton', ...
            'String', 'Stop Recording', ...
            'Position', [220 900 150 40], ...
            'FontSize', 12, ...
            'Callback', @stop_recording);
        
        uicontrol(tab2, 'Style', 'pushbutton', ...
            'String', 'Play Recording', ...
            'Position', [390 900 150 40], ...
            'FontSize', 12, ...
            'Callback', @play_recording);
        
        uicontrol(tab2, 'Style', 'pushbutton', ...
            'String', 'Export Data', ...
            'Position', [560 900 150 40], ...
            'FontSize', 12, ...
            'Callback', @export_data);
        
        % Recording info
        app.recordingInfo = uicontrol(tab2, 'Style', 'text', ...
            'String', 'Recording: Not active - Speak to record', ...
            'Position', [50 850 400 30], ...
            'FontSize', 12, 'HorizontalAlignment', 'left', ...
            'ForegroundColor', [0.5 0.5 0.5]);
        
        % Recording waveform display
        ax1 = axes('Parent', tab2, 'Position', [0.1 0.5 0.8 0.3]);
        app.recordingPlot = plot(ax1, 0);
        title(ax1, 'Recorded Audio - Start recording and speak');
        grid(ax1, 'on');
        xlabel('Samples'); ylabel('Amplitude');
        ylim([-1 1]);
        
        % Analysis results
        ax2 = axes('Parent', tab2, 'Position', [0.1 0.1 0.8 0.3]);
        axis(ax2, 'off');
        app.analysisText = text(ax2, 0.05, 0.95, {'No recording available.', 'Start recording and speak into microphone.'}, ...
            'FontSize', 11, 'VerticalAlignment', 'top', ...
            'FontName', 'FixedWidth', 'Interpreter', 'none', ...
            'Color', [0.5 0.5 0.5]);
    end

    function create_voice_tab()
        tab3 = uitab(app.tabGroup, 'Title', 'Voice Analysis');
        
        % Voice type detection
        ax1 = subplot(2,3,1, 'Parent', tab3);
        app.voiceTypeText = text(ax1, 0.5, 0.5, {'Voice Type:', 'No signal'}, ...
            'FontSize', 16, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'Interpreter', 'none', ...
            'Color', [0.5 0.5 0.5]);
        title(ax1, 'Voice Type Detection');
        set(ax1, 'XTick', [], 'YTick', []);
        
        % Pitch range analysis
        ax2 = subplot(2,3,2, 'Parent', tab3);
        app.pitchRangePlot = bar(ax2, [0 0 0], 'FaceColor', [0.7 0.7 0.7]);
        title(ax2, 'Pitch Range Distribution');
        set(ax2, 'XTickLabel', {'Low', 'Mid', 'High'});
        ylabel(ax2, 'Frequency');
        ylim(ax2, [0 10]);
        
        % Voice quality metrics
        ax3 = subplot(2,3,3, 'Parent', tab3);
        app.qualityBars = bar(ax3, [0 0], 'FaceColor', [0.7 0.7 0.7]);
        title(ax3, 'Voice Quality');
        set(ax3, 'XTickLabel', {'Stability', 'Clarity'});
        ylabel(ax3, 'Score (%)');
        ylim(ax3, [0 100]);
        
        % Formant analysis
        ax4 = subplot(2,3,4, 'Parent', tab3);
        app.formantPlot = scatter(ax4, 500, 1500, 100, 'filled', 'MarkerFaceColor', [0.7 0.7 0.7]);
        title(ax4, 'Formant Analysis (F1 vs F2)');
        xlabel(ax4, 'F1 (Hz)'); ylabel(ax4, 'F2 (Hz)');
        grid(ax4, 'on');
        xlim(ax4, [200 1000]); ylim(ax4, [500 2500]);
        
        % Speech characteristics
        ax5 = subplot(2,3,5, 'Parent', tab3);
        axis(ax5, 'off');
        app.voiceStatsText = text(ax5, 0.05, 0.95, {'Voice Characteristics:', 'No voice detected', 'Speak into microphone'}, ...
            'FontSize', 12, 'VerticalAlignment', 'top', 'Interpreter', 'none', ...
            'Color', [0.5 0.5 0.5]);
        
        % Emotion detection
        ax6 = subplot(2,3,6, 'Parent', tab3);
        app.emotionText = text(ax6, 0.5, 0.5, {'Emotion:', 'No signal'}, ...
            'FontSize', 14, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'Interpreter', 'none', ...
            'Color', [0.5 0.5 0.5]);
        title(ax6, 'Emotion Detection');
        set(ax6, 'XTick', [], 'YTick', []);
    end

    function create_music_tab()
        tab4 = uitab(app.tabGroup, 'Title', 'Music Analysis');
        
        % Tuner display
        ax1 = subplot(2,2,1, 'Parent', tab4);
        app.tunerNeedle = plot(ax1, [0 0], [-1 1], 'r-', 'LineWidth', 4);
        hold(ax1, 'on');
        plot(ax1, [-20 20], [0 0], 'k-', 'LineWidth', 2);
        for i = -20:10:20
            plot(ax1, [i i], [-0.1 0.1], 'k-', 'LineWidth', 1);
        end
        xlim(ax1, [-50 50]); ylim(ax1, [-1.5 1.5]);
        title(ax1, 'Tuner - Sing to See Pitch'); xlabel(ax1, 'Cents from target');
        set(ax1, 'YTick', []);
        grid(ax1, 'on');
        
        % Scale detection
        ax2 = subplot(2,2,2, 'Parent', tab4);
        app.scaleText = text(ax2, 0.5, 0.5, {'Scale: --', 'Key: --'}, ...
            'FontSize', 16, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'Interpreter', 'none', ...
            'Color', [0.5 0.5 0.5]);
        title(ax2, 'Scale & Key Detection');
        set(ax2, 'XTick', [], 'YTick', []);
        
        % Note history
        ax3 = subplot(2,2,3, 'Parent', tab4);
        app.noteHistoryPlot = plot(ax3, nan(50,1), 'o-', 'LineWidth', 2, 'Color', [0.7 0.7 0.7]);
        title(ax3, 'Note Sequence - Sing to See Notes');
        xlabel(ax3, 'Time'); ylabel(ax3, 'Note Value');
        grid(ax3, 'on');
        ylim(ax3, [0 12]);
        set(ax3, 'YTick', 0:12, 'YTickLabel', {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C'});
        
        % Music statistics
        ax4 = subplot(2,2,4, 'Parent', tab4);
        axis(ax4, 'off');
        app.musicStatsText = text(ax4, 0.05, 0.95, {'Music Analysis:', 'No audio detected', 'Sing into microphone'}, ...
            'FontSize', 12, 'VerticalAlignment', 'top', 'Interpreter', 'none', ...
            'Color', [0.5 0.5 0.5]);
    end

    function initialize_data()
        % Initialize data buffers
        app.maxHistory = 200;
        app.pitchHistory = nan(app.maxHistory, 1);
        app.volumeHistory = nan(app.maxHistory, 1);
        app.spectrogramData = zeros(128, app.maxHistory);
        app.noteHistory = nan(50, 1);
        
        % Analysis parameters
        app.vadThreshold = 0.005; % Voice activity detection threshold
        app.pitchRange = [50, 500];
        
        % Statistics
        app.frameCount = 0;
        app.voiceActiveFrames = 0;
        app.pitchValues = [];
        app.volumeValues = [];
        
        % Voice analysis data
        app.pitchRangeCounts = [0 0 0];
        app.voiceStability = 0;
        app.voiceClarity = 0;
        
        % Musical notes mapping
        app.notes = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'};
        
        % Control flags
        app.running = true;
        app.audioActive = false;
        
        fprintf('Microphone-only analyzer initialized.\n');
        fprintf('Speak or sing into your microphone to see analysis results.\n');
    end

    function start_analysis()
        % Main processing loop - MICROPHONE ONLY
        fprintf('Starting microphone-only analysis...\n');
        app.running = true;
        
        % Start microphone recording
        if app.audioInitialized
            record(app.recorder);
            fprintf('Microphone recording started. Speak now...\n');
        end
        
        while app.running && ishandle(app.fig)
            try
                % Get REAL audio only - no simulation
                audioData = get_real_audio();
                
                % Process audio frame
                process_audio_frame(audioData);
                
                % Update displays
                update_displays();
                
                % Handle recording
                if app.isRecording
                    if length(app.recordedAudio) < app.maxRecordingSamples
                        app.recordedAudio = [app.recordedAudio; audioData];
                    else
                        stop_recording([], []);
                    end
                    update_recording_display();
                end
                
                pause(0.05); % Control update rate
                
            catch ME
                fprintf('Processing error: %s\n', ME.message);
            end
        end
        
        cleanup();
    end

    function audioData = get_real_audio()
        % Get real audio from microphone only
        try
            % Get all available audio data
            allAudio = getaudiodata(app.recorder);
            
            if length(allAudio) > app.frameSize
                % Get the most recent frame
                startIdx = max(1, length(allAudio) - app.frameSize + 1);
                audioData = allAudio(startIdx:end);
                
                % Update level meter
                update_level_meter(audioData);
            else
                audioData = zeros(app.frameSize, 1);
            end
            
        catch ME
            fprintf('Real audio error: %s\n', ME.message);
            audioData = zeros(app.frameSize, 1); % Return silence on error
        end
    end

    function update_level_meter(audioData)
        % Update input level meter
        level = rms(audioData);
        
        if level < 0.001
            meterStr = '|----------| NO SIGNAL';
            color = [1 0 0]; % Red
            set(app.statusText, 'String', 'SPEAK INTO MICROPHONE TO START ANALYSIS', ...
                'BackgroundColor', [1 0.8 0.8], 'ForegroundColor', 'red');
        elseif level < 0.01
            meterStr = '|##--------| QUIET';
            color = [1 1 0]; % Yellow
            set(app.statusText, 'String', 'SPEAK LOUDER FOR BETTER ANALYSIS', ...
                'BackgroundColor', [1 1 0.8], 'ForegroundColor', 'orange');
        elseif level < 0.05
            meterStr = '|####------| GOOD';
            color = [0.8 0.8 0]; % Yellow
            set(app.statusText, 'String', 'ANALYZING YOUR VOICE - GOOD LEVEL', ...
                'BackgroundColor', [0.8 1 0.8], 'ForegroundColor', 'green');
        else
            meterStr = '|##########| LOUD';
            color = [0 1 0]; % Green
            set(app.statusText, 'String', 'ANALYZING YOUR VOICE - EXCELLENT', ...
                'BackgroundColor', [0.7 1 0.7], 'ForegroundColor', 'blue');
        end
        
        if ishandle(app.levelMeter)
            set(app.levelMeter, 'String', meterStr, 'ForegroundColor', color);
        end
    end

    function process_audio_frame(audioData)
        app.frameCount = app.frameCount + 1;
        
        % Compute basic features
        volume = rms(audioData);
        pitch = detect_pitch(audioData);
        
        % Voice activity detection
        isVoiceActive = volume > app.vadThreshold && ...
                       ~isnan(pitch) && ...
                       pitch >= app.pitchRange(1) && pitch <= app.pitchRange(2);
        
        if isVoiceActive
            app.voiceActiveFrames = app.voiceActiveFrames + 1;
            app.pitchValues = [app.pitchValues; pitch];
            app.volumeValues = [app.volumeValues; volume];
            app.audioActive = true;
            
            % Update analyses only when voice is active
            update_voice_analysis(pitch, volume);
            update_music_analysis(pitch);
        else
            app.audioActive = false;
            % Reset musical note display when no voice
            if ishandle(app.noteText)
                set(app.noteText, 'String', '--', 'Color', [0.5 0.5 0.5]);
            end
            if ishandle(app.tunerNeedle)
                set(app.tunerNeedle, 'XData', [0 0], 'Color', [0.7 0.7 0.7]);
            end
        end
        
        % Update histories
        idx = mod(app.frameCount - 1, app.maxHistory) + 1;
        app.volumeHistory(idx) = volume;
        
        if isVoiceActive
            app.pitchHistory(idx) = pitch;
        else
            app.pitchHistory(idx) = NaN;
        end
        
        % Update spectrogram only when audio is active
        if isVoiceActive
            update_spectrogram(audioData, idx);
        end
        
        % Update statistics
        update_statistics();
    end

    function pitch = detect_pitch(audioData)
        % Simple autocorrelation pitch detection
        try
            % Remove DC offset
            audioData = audioData - mean(audioData);
            
            if max(abs(audioData)) < 0.001
                pitch = NaN;
                return;
            end
            
            % Simple autocorrelation
            corr_len = min(512, length(audioData));
            corr = zeros(corr_len, 1);
            
            for k = 1:corr_len
                corr(k) = sum(audioData(1:end-k+1) .* audioData(k:end));
            end
            
            % Find first major peak after the zero-lag peak
            [peaks, locs] = findpeaks(corr(20:end)); % Skip very short lags
            if ~isempty(peaks)
                [~, max_idx] = max(peaks);
                fundamental_idx = locs(max_idx) + 19; % Adjust for offset
                
                if fundamental_idx > 0
                    pitch = app.fs / fundamental_idx;
                    
                    % Validate pitch range
                    if pitch < 50 || pitch > 500
                        pitch = NaN;
                    end
                else
                    pitch = NaN;
                end
            else
                pitch = NaN;
            end
            
        catch
            pitch = NaN;
        end
    end

    function update_spectrogram(audioData, idx)
        % Simple spectrogram update - only when voice is active
        try
            % Use FFT for spectrum
            N = min(256, length(audioData));
            fft_data = abs(fft(audioData, N));
            fft_data = fft_data(1:N/2);
            
            % Log scale and normalize
            spec_data = 10*log10(fft_data + eps);
            spec_data = spec_data - min(spec_data);
            if max(spec_data) > 0
                spec_data = spec_data / max(spec_data) * 64;
            end
            
            % Resize to fit spectrogram matrix
            if length(spec_data) >= 64
                app.spectrogramData(:, idx) = spec_data(1:64);
            end
            
        catch
            % Skip on error
        end
    end

    function update_voice_analysis(pitch, volume)
        % Update voice type only when voice is active
        if pitch < 120
            voiceType = 'Bass';
            voiceColor = [0.2 0.2 0.8];
            app.pitchRangeCounts(1) = app.pitchRangeCounts(1) + 1;
        elseif pitch < 180
            voiceType = 'Baritone';
            voiceColor = [0.2 0.6 0.8];
            app.pitchRangeCounts(2) = app.pitchRangeCounts(2) + 1;
        elseif pitch < 250
            voiceType = 'Tenor';
            voiceColor = [0.8 0.6 0.2];
            app.pitchRangeCounts(2) = app.pitchRangeCounts(2) + 1;
        elseif pitch < 350
            voiceType = 'Alto';
            voiceColor = [0.8 0.2 0.6];
            app.pitchRangeCounts(3) = app.pitchRangeCounts(3) + 1;
        else
            voiceType = 'Soprano';
            voiceColor = [0.8 0.2 0.2];
            app.pitchRangeCounts(3) = app.pitchRangeCounts(3) + 1;
        end
        
        % Update displays
        if ishandle(app.voiceTypeText)
            set(app.voiceTypeText, 'String', {sprintf('Voice Type: %s', voiceType), sprintf('%.0f Hz', pitch)}, ...
                'Color', voiceColor);
        end
        
        if ishandle(app.pitchRangePlot)
            set(app.pitchRangePlot, 'YData', app.pitchRangeCounts, 'FaceColor', [0.2 0.6 0.8]);
        end
        
        % Update quality metrics
        if length(app.pitchValues) > 5
            recent_pitches = app.pitchValues(max(1, end-4):end);
            pitch_std = std(recent_pitches);
            app.voiceStability = max(0, 100 - pitch_std * 5);
            app.voiceClarity = min(100, volume * 800);
            
            if ishandle(app.qualityBars)
                set(app.qualityBars, 'YData', [app.voiceStability, app.voiceClarity], 'FaceColor', [0.2 0.6 0.8]);
            end
        end
        
        % Update statistics
        if ishandle(app.voiceStatsText)
            if length(app.pitchValues) > 2
                statsStr = {sprintf('Voice Characteristics:'), ...
                           sprintf('Current Pitch: %.0f Hz', pitch), ...
                           sprintf('Stability: %.1f%%', app.voiceStability), ...
                           sprintf('Clarity: %.1f%%', app.voiceClarity), ...
                           sprintf('Voice Type: %s', voiceType)};
            else
                statsStr = {'Voice Characteristics:', 'Analyzing...'};
            end
            set(app.voiceStatsText, 'String', statsStr, 'Color', 'black');
        end
        
        % Emotion detection
        if volume > 0.05
            emotion = 'Excited';
            emotionColor = [1 0.5 0];
        elseif volume < 0.005
            emotion = 'Calm';
            emotionColor = [0 0.6 1];
        else
            emotion = 'Neutral';
            emotionColor = [0.3 0.3 0.3];
        end
        
        if ishandle(app.emotionText)
            set(app.emotionText, 'String', {'Emotion:', emotion}, ...
                'Color', emotionColor);
        end
    end

    function update_music_analysis(pitch)
        % Convert to musical note only when voice is active
        [noteName, cents] = convert_to_note(pitch);
        
        % Update displays
        if ishandle(app.noteText)
            if abs(cents) < 5  % Very close to perfect pitch
                set(app.noteText, 'String', sprintf('%s\n(perfect)', noteName), ...
                    'Color', [0 0.7 0], 'FontSize', 20);
            elseif cents < 0  % Flat
                set(app.noteText, 'String', sprintf('%s\n(%d¢ flat)', noteName, abs(cents)), ...
                    'Color', [0.8 0.2 0.2], 'FontSize', 18);
            else  % Sharp
                set(app.noteText, 'String', sprintf('%s\n(%d¢ sharp)', noteName, cents), ...
                    'Color', [0.8 0.2 0.2], 'FontSize', 18);
            end
        end
        
        % Update tuner needle
        if ishandle(app.tunerNeedle)
            cents = max(-50, min(50, cents)); % Limit to ±50 cents for display
            set(app.tunerNeedle, 'XData', [cents cents], 'Color', 'red', 'LineWidth', 4);
        end
        
        % Update note history
        noteValue = mod(round(12 * log2(pitch / 440)), 12);
        if ~isnan(noteValue)
            app.noteHistory = [app.noteHistory(2:end); noteValue];
        end
        
        if ishandle(app.noteHistoryPlot)
            set(app.noteHistoryPlot, 'YData', app.noteHistory, 'Color', 'blue', ...
                'MarkerFaceColor', 'blue', 'LineWidth', 2);
        end
        
        % Update scale and key detection (FIXED FUNCTION)
        update_scale_detection();
        
        % Update music statistics
        if ishandle(app.musicStatsText)
            if length(app.pitchValues) > 10
                recent_pitches = app.pitchValues(max(1, end-9):end);
                pitch_std = std(recent_pitches);
                accuracy = max(0, 100 - pitch_std * 2);
                
                statsStr = {sprintf('Music Analysis:'), ...
                           sprintf('Current Note: %s', noteName), ...
                           sprintf('Accuracy: %.1f%%', accuracy), ...
                           sprintf('Tuning: %+d cents', cents)};
            else
                statsStr = {sprintf('Music Analysis:'), ...
                           sprintf('Current Note: %s', noteName), ...
                           sprintf('Tuning: %+d cents', cents), ...
                           'Keep singing...'};
            end
            set(app.musicStatsText, 'String', statsStr, 'Color', 'black');
        end
    end

    function update_scale_detection()
        % Fixed scale and key detection function
        if length(app.pitchValues) < 5
            % Not enough data yet
            scaleStr = {'Scale: --', 'Key: --'};
            scaleColor = [0.5 0.5 0.5];
        else
            % Get recent pitches for analysis
            recent_pitches = app.pitchValues(max(1, end-4):end);
            
            % Convert pitches to note values
            note_values = [];
            for i = 1:length(recent_pitches)
                [~, cents] = convert_to_note(recent_pitches(i));
                if abs(cents) < 25  % Only count if reasonably in tune
                    semitones = 12 * log2(recent_pitches(i) / 440);
                    note_val = mod(round(semitones), 12);
                    note_values = [note_values, note_val];
                end
            end
            
            if length(note_values) >= 3
                % Simple scale detection based on common patterns
                unique_notes = unique(note_values);
                
                if length(unique_notes) <= 5
                    % Major scale pattern detection
                    if any(ismember([0,2,4,5,7,9,11], unique_notes))
                        scaleType = 'Major';
                        keyNote = mode(note_values);
                        keyName = app.notes{keyNote + 1};
                        scaleStr = {sprintf('Scale: %s', scaleType), sprintf('Key: %s', keyName)};
                        scaleColor = [0 0.5 0];
                    % Minor scale pattern detection  
                    elseif any(ismember([0,2,3,5,7,8,10], unique_notes))
                        scaleType = 'Minor';
                        keyNote = mode(note_values);
                        keyName = app.notes{keyNote + 1};
                        scaleStr = {sprintf('Scale: %s', scaleType), sprintf('Key: %s', keyName)};
                        scaleColor = [0.5 0 0.5];
                    else
                        scaleStr = {'Scale: Unknown', 'Key: Detecting...'};
                        scaleColor = [0.8 0.4 0];
                    end
                else
                    scaleStr = {'Scale: Complex', 'Key: Multiple'};
                    scaleColor = [0.8 0.4 0];
                end
            else
                scaleStr = {'Scale: --', 'Key: --'};
                scaleColor = [0.5 0.5 0.5];
            end
        end
        
        if ishandle(app.scaleText)
            set(app.scaleText, 'String', scaleStr, 'Color', scaleColor);
        end
    end

    function [noteName, cents] = convert_to_note(freq)
        % Convert frequency to musical note with cents accuracy
        A4 = 440; % Standard tuning frequency
        
        if freq <= 0 || isnan(freq)
            noteName = '--';
            cents = 0;
            return;
        end
        
        % Calculate semitones from A4
        semitones = 12 * log2(freq / A4);
        
        % Round to nearest semitone to get note index
        noteIndex = round(semitones);
        cents = round((semitones - noteIndex) * 100);
        
        % Convert note index to note name (0 = A, 1 = A#, etc.)
        noteNames = {'A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#'};
        noteNameIndex = mod(noteIndex, 12);
        if noteNameIndex < 0
            noteNameIndex = noteNameIndex + 12;
        end
        
        noteName = noteNames{noteNameIndex + 1};
        
        % Calculate octave (A4 is our reference)
        octave = 4 + floor((noteIndex + 9) / 12);
        noteName = sprintf('%s%d', noteName, octave);
    end

    function update_statistics()
        % Calculate and display statistics
        voiceActivityPercent = (app.voiceActiveFrames / max(1, app.frameCount)) * 100;
        
        validPitches = app.pitchHistory(~isnan(app.pitchHistory));
        if ~isempty(validPitches)
            currentPitch = validPitches(end);
            avgPitch = mean(validPitches);
            pitchStd = std(validPitches);
        else
            currentPitch = NaN;
            avgPitch = NaN;
            pitchStd = NaN;
        end
        
        currentVolume = app.volumeHistory(mod(app.frameCount-1, app.maxHistory)+1);
        if isnan(currentVolume), currentVolume = 0; end
        
        if app.audioActive
            statusText = 'VOICE ACTIVE';
            statsColor = 'black';
            modeInfo = 'MICROPHONE - VOICE DETECTED';
        else
            statusText = 'NO VOICE - SPEAK NOW';
            statsColor = [0.5 0.5 0.5];
            modeInfo = 'MICROPHONE - WAITING FOR INPUT';
        end
        
        statsString = sprintf(['%s\n' ...
            '===============\n' ...
            'Frames: %d\n' ...
            'Voice Activity: %.1f%%\n' ...
            'Current Pitch: %.1f Hz\n' ...
            'Avg Pitch: %.1f Hz\n' ...
            'Current Volume: %.4f\n' ...
            'Status: %s'], ...
            modeInfo, app.frameCount, voiceActivityPercent, currentPitch, avgPitch, ...
            currentVolume, statusText);
        
        if ishandle(app.statsText)
            set(app.statsText, 'String', statsString, 'Color', statsColor);
        end
    end

    function update_displays()
        if ~ishandle(app.fig), return; end
        
        try
            % Get current audio data
            currentAudio = get_real_audio();
            
            % Update waveform
            set(app.waveformPlot, 'YData', currentAudio);
            if app.audioActive
                title(app.waveformPlot.Parent, 'Audio Waveform - LIVE VOICE');
            else
                title(app.waveformPlot.Parent, 'Audio Waveform - Speak to See Signal');
            end
            
            % Update spectrum
            N = 512;
            fft_data = abs(fft(currentAudio, N));
            fft_db = 20*log10(fft_data(1:N/2) + eps);
            freq_axis = (0:N/2-1) * app.fs / N;
            set(app.spectrumPlot, 'XData', freq_axis, 'YData', fft_db);
            if app.audioActive
                title(app.spectrumPlot.Parent, 'Frequency Spectrum - LIVE VOICE');
            else
                title(app.spectrumPlot.Parent, 'Frequency Spectrum - Speak to See Spectrum');
            end
            
            % Update history plots
            set(app.pitchPlot, 'YData', app.pitchHistory);
            set(app.volumePlot, 'YData', app.volumeHistory);
            
            % Update spectrogram
            set(app.spectrogram, 'CData', app.spectrogramData);
            if app.audioActive
                title(app.spectrogram.Parent, 'Real-time Spectrogram - LIVE VOICE');
            else
                title(app.spectrogram.Parent, 'Real-time Spectrogram - Speak to See Spectrogram');
            end
            
            % Update voice activity indicator
            if app.audioActive
                set(app.vadIndicator, 'FaceColor', [0 1 0]); % Green
            else
                set(app.vadIndicator, 'FaceColor', [1 0 0]); % Red
            end
            
            drawnow limitrate;
            
        catch ME
            fprintf('Display update error: %s\n', ME.message);
        end
    end

    % Callback functions
    function start_recording(~, ~)
        app.isRecording = true;
        app.recordedAudio = [];
        app.recordingStartTime = tic;
        set(app.recordingInfo, 'String', 'Recording: ACTIVE - Speak into microphone', ...
            'ForegroundColor', 'red', 'FontWeight', 'bold');
        fprintf('Recording started...\n');
    end

    function stop_recording(~, ~)
        app.isRecording = false;
        recordingTime = toc(app.recordingStartTime);
        set(app.recordingInfo, 'String', ...
            sprintf('Recording: STOPPED (%.1f seconds)', recordingTime), ...
            'ForegroundColor', 'black', 'FontWeight', 'normal');
        
        analyze_recording();
        fprintf('Recording stopped. Duration: %.1f seconds\n', recordingTime);
    end

    function play_recording(~, ~)
        if ~isempty(app.recordedAudio)
            try
                sound(app.recordedAudio, app.fs);
                fprintf('Playing recording...\n');
            catch
                fprintf('Error playing recording.\n');
            end
        else
            fprintf('No recording to play.\n');
        end
    end

    function export_data(~, ~)
        try
            timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
            
            % Save audio
            if ~isempty(app.recordedAudio)
                filename = sprintf('speech_analysis_%s.wav', timestamp);
                audiowrite(filename, app.recordedAudio, app.fs);
                fprintf('Audio saved as: %s\n', filename);
            end
            
            % Save analysis data
            data = struct();
            data.pitchHistory = app.pitchHistory;
            data.volumeHistory = app.volumeHistory;
            data.spectrogramData = app.spectrogramData;
            data.recordingTime = toc(app.recordingStartTime);
            data.sampleRate = app.fs;
            
            filename = sprintf('analysis_data_%s.mat', timestamp);
            save(filename, 'data');
            fprintf('Analysis data saved as: %s\n', filename);
            
        catch ME
            fprintf('Export error: %s\n', ME.message);
        end
    end

    function analyze_recording()
        if isempty(app.recordedAudio)
            return;
        end
        
        try
            % Analyze the recorded audio
            analysisStr = {'Recording Analysis:', ...
                sprintf('Duration: %.2f seconds', length(app.recordedAudio)/app.fs), ...
                sprintf('Samples: %d', length(app.recordedAudio)), ...
                '', 'Processing complete.'};
            
            % Update recording plot
            set(app.recordingPlot, 'XData', 1:length(app.recordedAudio), ...
                'YData', app.recordedAudio);
            
            % Update analysis text
            set(app.analysisText, 'String', analysisStr, 'Color', 'black');
            
        catch ME
            fprintf('Analysis error: %s\n', ME.message);
        end
    end

    function update_recording_display()
        if ~isempty(app.recordedAudio)
            set(app.recordingPlot, 'XData', 1:length(app.recordedAudio), ...
                'YData', app.recordedAudio);
            drawnow;
        end
    end

    function close_app(~, ~)
        app.running = false;
        cleanup();
        delete(app.fig);
    end

    function cleanup()
        try
            if ~isempty(app.recorder) && isrecording(app.recorder)
                stop(app.recorder);
            end
            fprintf('Cleanup completed.\n');
        catch
        end
    end

end % End of main function
