% HPLC2Spect - a 2D-chromatogram analysis tool
% F. Steffen, 2017-2019

function hplc2spect

% initialize GUI
main = figure('name', 'HPLC2Spect', 'Position',[500 300 700 400],...
    'menubar', 'none', 'NumberTitle', 'off', 'resize', 'off');

% customize toolbar
set(gcf, 'Toolbar','figure')
Hcam=findobj(allchild(gcf),'tag','FigureToolBar');
v=allchild(Hcam);
set(v,'visible','off')
zoomIn=findobj(v,'tooltip','Zoom In');
zoomOut=findobj(v,'tooltip','Zoom Out');
panning=findobj(v,'tooltip','Pan');
set(zoomIn,'visible','on')
set(zoomOut,'visible','on')
set(panning,'visible','on')

% menu
myFile = uimenu('Label', 'File');
myProcessing = uimenu('Label', 'Processing');
myHelp = uimenu('Label', 'Help');
uimenu(myFile,'Label','Open File(s)','Callback',@fn_open);
saveMenu = uimenu(myFile,'Label','Save Image','Callback', @fn_save);
uimenu(myFile,'Label','Options','Callback', @fn_options);
cutMenu = uimenu(myProcessing,'Label','Crop/Save Chromatogram','Callback', @fn_cutSpect);
extractMenu = uimenu(myProcessing,'Label','Extract Trace/Spectrum','Callback', @fn_extractTraceSpect);
uimenu(myHelp,'Label','HPLC2Spect Help','Callback', @fn_helpMe);
uimenu(myHelp,'Label','About HPLC2Spect','Callback', @fn_About);

set(saveMenu,'Enable','off');
set(cutMenu,'Enable','off');
set(extractMenu,'Enable','off');

% axes
axRet = axes('Units','Pixels','Position',[70,270,430,80], 'visible','off', 'XTickLabel','', 'YTickLabel','');
axSpect = axes('Units','Pixels','Position',[590,60,80,200], 'visible','off', 'XTickLabel','', 'YTickLabel','');
ax = axes('Units','Pixels','Position',[70,60,430,200], 'visible','off');
linkaxes([ax,axRet],'x')
linkaxes([ax,axSpect],'y')

filename = 'chromatogram';

% initialize chromatogram selection popupmenu
select_trace = uicontrol('Style','popupmenu',...
    'String',filename,...
    'Position',[70,370,150,25],...
    'tooltipstring', 'chromatogram(s)',...
    'Enable', 'Off',...
    'Callback',@drawChroma);

% pushbutton for defining the evaluation subrange
defineArea = uicontrol('Style','pushbutton',...
    'String','define area',...
    'Position',[245,370,100,25],...
    'Enable', 'off',...
    'tooltipstring', 'define a rectangular range within the 2D chromatogram which is searched for the peak maximum',...
    'Callback',@getArea);

% pushbutton for manual selection of value withing the 2D chromatogram
manualCrosshair = uicontrol('Style','pushbutton',...
    'String','manual',...
    'Position',[370,370,100,25],...
    'Enable', 'off',...
    'tooltipstring', 'manually define a retention time and wavelength',...
    'Callback',@getManual);

% pushbutton for finding the maximum value within the subrange
lockingPos = uicontrol('Style','radiobutton',...
    'String','lock position',...
    'Position',[495,370,100,25],...
    'Enable', 'off',...
    'tooltipstring', 'lock the current retention time and wavelength in the spectrum',...
    'Callback',@lockPosition);

infoBox = uicontrol('Style','edit',...
    'String','Welcome to HPLC2Spect!',...
    'Position',[520,290,150,60],...
    'HorizontalAlignment', 'left',...
    'max', 2);

% default options
setappdata(main, 'delimiter', '\t');
setappdata(main, 'time_col', '1');
setappdata(main, 'wavelength_col_fromTo', {'3', 'end'});
setappdata(main, 'wavelength_fromTo', {'200', '800'});
setappdata(main, 'row_fromTo', {'2', 'end'});
setappdata(main, 'tick_manual', 0);

% open dialog
    function fn_open(~,~)
        
        % open dialog
        [filename, pathname] = uigetfile({sprintf('*.%s', 'txt'), sprintf('%s (*.%s)', 'Text files', 'txt')}, 'Please select chromatogram file(s)', 'Multiselect', 'on');
        if length(filename) == 1
            return
        end
        %disp(filename)
        cd(pathname)
        if ~iscell(filename)
            filename = {filename};
        end
        setappdata(main, 'filename', filename)
        
        % initalize containers
        samples = size(filename,2);
        file = cell(1,size(filename,2));
        head = cell(1, length(filename));
        head2 = cell(1, length(filename));
        data = cell(1, length(filename));
        data2 = cell(1, length(filename));
        startwave = cell(1, length(filename));
        endwave = cell(1, length(filename));
        starttime = cell(1, length(filename));
        endtime = cell(1, length(filename));
        wavelengths = cell(1, length(filename));
        times = cell(1, length(filename));
        img = cell(1, length(filename));
        n = cell(1, length(filename));
        
        
        delimiter = getappdata(main, 'delimiter');
        time_col = getappdata(main, 'time_col');
        wavelength_col_fromTo = getappdata(main, 'wavelength_col_fromTo');
        wavelength_fromTo = getappdata(main, 'wavelength_fromTo');
        row_fromTo = getappdata(main, 'row_fromTo');
        tick_manual = getappdata(main, 'tick_manual');
        
        % initalize waitbar
        w = waitbar(0, sprintf('Loading chromatogram %d/%d', 1,samples), 'position', [310, 350 270, 50]);
        increment = 1/(3*samples);
        
        %------------------------------------------
        % USER Definition
        % characters to replace from file
        repl_from_to = {{'''', 'n.a.'}, {'', '0'}};
        %------------------------------------------
        
        for i = 1:samples
            waitbar(3*(i-1)*increment+increment,w, sprintf('Loading chromatogram %d/%d', i,samples), 'position', [310, 350 270, 50])
            
            % opening file as a character string
            file{i} = filename{i}(1:end-4);
            fid = fopen(filename{i}, 'rt');
            whole_file = fscanf(fid,'%c');
            fclose(fid);
            waitbar(3*(i-1)*increment+2*increment,w, sprintf('Loading chromatogram %d/%d', i,samples), 'position', [310, 350 270, 50])
            
            % replace all characters in repl_from_to from the file, e.g. thousand separator and n.a.
            for j = 1:length(repl_from_to{1})
                whole_file = strrep(whole_file, repl_from_to{1}{j}, repl_from_to{2}{j});
            end
            
            if tick_manual == 0
                % automatic header detection and reading wavelengths
                % directly from the file
                % (see example file for how to format)
                
                cycles = 605; % the wavelength range is from 200-800 at most (605 cycles should be enough)
                head_id = repmat('%s',1, cycles);
                data_id = repmat('%f',1, cycles);

                % scan file as string to get the position of the header
                head_scan = textscan(whole_file,head_id,'delimiter',delimiter);
                num_ind = ~isnan(str2double(head_scan{1})); % find numeric data           
            
                % check if header string with wavelengths is present
                if num_ind(1) == 1
                    set(infoBox, 'String', 'No wavelength information present in header. See folder "examples" or specify wavelength limits manually in File->Options')
                    close(w)
                    return
                else
                    % one or more headerlines
                    [~, pos] = textscan(whole_file,head_id,find(num_ind,1)-2,'delimiter',delimiter);
                    [head{i}, pos2] = textscan(whole_file(pos+1:end),head_id,1,'delimiter',delimiter);
                    try 
                        data{i} = textscan(whole_file(pos+pos2+1:end),data_id, 'delimiter',delimiter);
                    catch
                        close(w)
                        set(infoBox, 'String', 'Cannot read file with automatic header detection, wrong format. Try manual import with parameters from File->Options')
                        return
                    end
                    waitbar(3*(i-1)*increment+4*increment,w, sprintf('Loading chromatogram %d/%d', i,samples), 'position', [310, 350 270, 50])

                    for j = 1:cycles 
                        head2{i}(j) = str2double(head{i}{j});
                    end
                    wavelengths{i} = head2{i}(~isnan(head2{i}));
                    startwave{i} = min(head2{i});
                    endwave{i} = max(head2{i});
                    n{i} = find(endwave{i}==head2{i});
                    data2{i} = cell2mat(data{i}(1:n{i}));
                end
            else
                try
                    % import file manually with parameters specified in
                    % File->Options
                    clipboard('copy',whole_file)
                    data2{i} = importdata('-pastespecial',delimiter, str2double(row_fromTo{1})-1);
                    
                    % the following line only works in MATLAB >2019a
                    %data2{i} = readmatrix(filename{i}, 'delimiter', delimiter, 'NumHeaderLines', str2double(row_fromTo{1})-1, 'ThousandsSeparator', '''');
                catch
                    close(w)
                    set(infoBox, 'String', 'Cannot read file, wrong format or wrong parameters in File->Options')
                    return
                end
                n_col = sum(~isnan(data2{i}(1,:)));
                data2{i} = data2{i}(:,1:n_col);
                wavelengths{i} = linspace(str2double(wavelength_fromTo{1}), str2double(wavelength_fromTo{2}), n_col-str2double(wavelength_col_fromTo{1})+1);
                startwave{i} = str2double(wavelength_fromTo{1});
                endwave{i} = str2double(wavelength_fromTo{2});
            end
            
            times{i} = data2{i}(:,str2double(time_col));
            starttime{i} = data2{i}(1,str2double(time_col));
            endtime{i} = data2{i}(end,str2double(time_col));
            if strcmp(wavelength_col_fromTo{2}, 'end')
                img{i} = flipud(data2{i}(:,str2double(wavelength_col_fromTo{1}):end)');
            else
                img{i} = flipud(data2{i}(:,str2double(wavelength_col_fromTo{1}):str2double(wavelength_col_fromTo{2}))');
            end
        end
        
        % close waitbar
        close(w)
        
        % make variables available
        setappdata(main, 'head', head)
        setappdata(main, 'head2', head2)
        setappdata(main, 'data2', data2)
        setappdata(main, 'endwave', endwave)
        setappdata(main, 'startwave', startwave)
        setappdata(main, 'endtime', endtime)
        setappdata(main, 'starttime', starttime)
        setappdata(main, 'times', times)
        setappdata(main, 'wavelengths', wavelengths)
        setappdata(main, 'img', img)
        setappdata(main, 'n', n)
        setappdata(main, 'select_trace', select_trace)
        
        % set parameters for the chromatogram selection popupmenu
        set(select_trace, 'Value', 1);
        set(select_trace, 'Enable', 'on')
        set(select_trace, 'String', filename)
        
        % draw chromatogram
        setappdata(main, 'traceValPrev', 1);
        drawChroma
        
        % enable save menu option
        set(saveMenu,'Enable','on');
        set(cutMenu,'Enable','on');

        if samples == 1
            set(infoBox, 'String', sprintf('%d data file was loaded...', samples))
        else
            set(infoBox, 'String', sprintf('%d data files were loaded...', samples))
        end
    end

    function drawChroma(~,~)
        
        % clear axes
        cla(ax)
        
        % get variables
        img = getappdata(main, 'img');
        startwave = getappdata(main, 'startwave');
        endwave = getappdata(main, 'endwave');
        starttime = getappdata(main, 'starttime');
        endtime = getappdata(main, 'endtime');
        select_trace = getappdata(main, 'select_trace');
        traceVal = get(select_trace, 'Value');
        
        yChromalimits = [startwave{traceVal} endwave{traceVal}];
        xChromalimits = [starttime{traceVal} endtime{traceVal}];
        setappdata(main, 'yChromalimits', yChromalimits);
        setappdata(main, 'xChromalimits', xChromalimits);
        
        % setting tick limits
        set(ax, 'Ylim',yChromalimits)
        set(ax, 'Xlim',xChromalimits)
        
        % get axis-limits
        Ly = get(ax, 'YLim');
        Lx = get(ax, 'XLim');
        
        % draw the chromatogram
        imagesc(linspace(Lx(1), Lx(2), size(img{traceVal},2)), linspace(Ly(2), Ly(1), size(img{traceVal},1)), img{traceVal})
        set(ax,'YDir','normal')
        
        % set the axes labels
        xlabel(ax, 'time (min)')
        ylabel(ax, 'wavelength (nm)')
        
        % clear axes of the traces (when changing the chromatogram)
        cla(axRet)
        cla(axSpect)
        
        % get position of ax before adding colorbar
        q = get(ax, 'Position');
        % create colormap
        M = 101;
        WB = linspace(1,0,M/2+1)';
        WR = linspace(0,1,M/2+1)';
        RB = linspace(0.98,0,M/2)';
        whiteREDblack = horzcat([ones(size(WR)); RB], [WB; zeros(size(RB))], [WB; zeros(size(RB))]);
        colormap(whiteREDblack)
        cb = colorbar(ax,  'ticklength', 0.035);
        setappdata(main, 'cb', cb);
        
        %restore position of ax after adding colorbar
        set(ax,'position',q)
        set(ax,'position',q)
        
        % make axis visible
        set(ax, 'visible', 'on', 'TickLength',[0.015 0.015]);
        set(axRet,'visible','on', 'TickLength',[0.015 0.015]);
        set(axSpect,'visible','on', 'TickLength',[0.03 0.03]);
        box(axRet,'on')
        box(axSpect,'on')
        set(manualCrosshair, 'Enable', 'On')
        set(defineArea, 'Enable', 'On')
        
        % check whether peak locking is activated
        lockPosition
        setappdata(main, 'traceValPrev', traceVal);
    end


    function getArea(~,~)
        
        % get variables
        img = getappdata(main, 'img');
        traceVal = get(select_trace, 'Value');
        
        % draw custom rectangle
        h = drawrectangle(ax); %#ok<IMRECT>
        %setColor(h, [0.8 0.8 0.8])
        posRect = h.Position;
        
        % get position index of rectangle
        posRectInd = posRect;
        posRectInd(1:2) = pos2Ind(posRect(1:2));
        posRectInd(3:4) = pos2Ind(posRect(1:2)+posRect(3:4));
        
        % get rectangle data subset
        s = size(img{traceVal});
        try
            imgRect = img{traceVal}((s(1)-posRectInd(4)):(s(1)-(posRectInd(2))), posRectInd(1):posRectInd(3));
            % create logical array with imgRect in img
            imgRectIndex = img;
            imgRectIndex{traceVal}((s(1)-posRectInd(4)):(s(1)-(posRectInd(2))), posRectInd(1):posRectInd(3)) = 1;
            imgRectIndex{traceVal}(imgRectIndex{traceVal}~=1) = 0;
        catch
            set(infoBox, 'String', 'selection out of 2D chromatogram')
            delete(h)
            return
        end
        
        % get maximum intensity
        ind = find(img{traceVal} == max(max(imgRect)));
        indRect = find(ismember(ind, find(logical(imgRectIndex{traceVal}))),1);
        [rows, cols] = ind2sub(s,ind(indRect));
        posInd = [rows, cols];
        %sprintf('max: %f', max(max(imgRect)))
        
        % get position from rows and cols
        posInd(1) = s(1)-posInd(1);
        pos = Ind2pos(fliplr(posInd));
        
        % make variable available
        setappdata(main, 'pos', pos);
        
        % delete rectangle
        delete(h)
        
        drawTrace
        
        set(lockingPos, 'Enable', 'On')
        
    end

    function posInd = pos2Ind(x, varargin)
        times = getappdata(main, 'times');
        wavelengths = getappdata(main, 'wavelengths');
        traceVal = get(select_trace, 'Value');
        
        % get closest positions within discretized image (times, wavelengths)
        [~, ind1] = min(abs(times{traceVal}-x(1)));
        [~, ind2] = min(abs(wavelengths{traceVal}-x(2)));
        
        % position on previous image
        if nargin > 1
            traceValPrev = getappdata(main, 'traceValPrev');
            [~, ind1] = min(abs(times{traceValPrev}-x(1)));
            [~, ind2] = min(abs(wavelengths{traceValPrev}-x(2)));
        end
        
        posInd = [ind1 ind2];
    end


    function pos = Ind2pos(x)
        times = getappdata(main, 'times');
        wavelengths = getappdata(main, 'wavelengths');
        traceVal = get(select_trace, 'Value');
        
        pos = x;
        pos(1) = times{traceVal}(x(1));
        pos(2) = wavelengths{traceVal}(x(2));
        
        setappdata(main, 'pos', pos)
    end


    function drawTrace(~,~)
        
        % get variables
        img = getappdata(main, 'img');
        pos = getappdata(main, 'pos');
        traceVal = get(select_trace, 'Value');
        times = getappdata(main, 'times');
        wavelengths = getappdata(main, 'wavelengths');
        s = size(img{traceVal});
        
        % get position index
        posInd = pos2Ind(pos);
        
        % delete existing lines
        try
            p1 = getappdata(main, 'p1');
            p2 = getappdata(main, 'p2');
            p3 = getappdata(main, 'p3');
            p4 = getappdata(main, 'p4');
            t1 = getappdata(main, 't1');
            t2 = getappdata(main, 't2');
            t3 = getappdata(main, 't3');
            delete(p1)
            delete(p2)
            delete(p3)
            delete(p4)
            delete(t1)
            delete(t2)
            delete(t3)
        catch
        end
        
        % draw selection lines
        hold on
        p1 = plot(ones(1,length(wavelengths{traceVal})).*pos(1),wavelengths{traceVal},':', 'Color', 'k', 'linewidth', 1);
        p2 = plot(times{traceVal}, ones(1,length(times{traceVal})).*pos(2),':', 'Color', 'k', 'linewidth', 1);
        
        % draw traces
        try
            
            hold(axSpect,'on')
            hold(axRet,'on')
            p3 = plot(axSpect, img{traceVal}(:,posInd(1)),fliplr(wavelengths{traceVal}), 'color', 'k', 'linewidth', 1);
            p4 = plot(axRet, times{traceVal},img{traceVal}(s(1)-posInd(2),:), 'color', 'k', 'linewidth', 1);
            hold(axSpect,'off')
            hold(axRet,'off')
        catch
            set(infoBox, 'String', 'selection out of 2D chromatogram')
        end      
        
        % hide TickLabels for trace-axes
        set(axRet,'XTickLabel','')
        set(axRet,'YTickLabel','')
        set(axSpect,'XTickLabel','')
        set(axSpect,'YTickLabel','')
        
        % set ticklength for all axes
        set(ax, 'TickLength',[0.015 0.015]);
        set(axRet,'TickLength',[0.015 0.015]);
        set(axSpect,'TickLength',[0.03 0.03]);
        
        % set axis-limits
        Ly = get(ax, 'YLim');
        Lx = get(ax, 'XLim');
        ylim(Ly)
        xlim(Lx)
        
        % get intensity value of intersection
        intensityVal = img{traceVal}(s(1)-posInd(2),posInd(1));
        %sprintf('intersection intensity: %f', intensityVal)
        
        % write wavelength and time
        t1 = text(0.025, 0.94,sprintf('wavelength: %0.0f nm', pos(2)),'units', 'normalized','HorizontalAlignment', 'left', 'color', [0.5 0.5 0.5]);
        t2 = text(0.975, 0.94,1,sprintf('time: %0.2f min', pos(1)),'units', 'normalized','HorizontalAlignment', 'right', 'color', [0.5 0.5 0.5]);
        t3 = text(0.5, 0.94,1,sprintf('I = %d', intensityVal),'units', 'normalized','HorizontalAlignment', 'center', 'color', [0.5 0.5 0.5]);
        
        % make lines available
        setappdata(main, 'p1', p1)
        setappdata(main, 'p2', p2)
        setappdata(main, 'p3', p3)
        setappdata(main, 'p4', p4)
        setappdata(main, 't1', t1)
        setappdata(main, 't2', t2)
        setappdata(main, 't3', t3)
        
        % Enable trace/spectrum extractMenu
        set(extractMenu,'Enable','on');
        set(infoBox, 'String', 'Extract peak position from ROI')
    end


    function getManual(~,~)
        [x,y] = ginput(1);     % crosshair
        pos = [x y];
        setappdata(main, 'pos', pos)
        drawTrace
        set(lockingPos, 'Enable', 'On')
        set(infoBox, 'String', 'Setting peak position manually')
    end


    function lockPosition(~,~)
        % keep the intersection lines and trace/spectrum when toggling between chromatograms

        % get variables
        traceValPrev = getappdata(main, 'traceValPrev');    
        traceVal = get(select_trace, 'Value');
        img = getappdata(main, 'img');
        s = size(img{traceValPrev});
        times = getappdata(main, 'times');
        wavelengths = getappdata(main, 'wavelengths');

        if get(lockingPos, 'Value') == 1
            
            % get position index
            pos = getappdata(main, 'pos');
            posInd = pos2Ind(pos, 'prev');
            
            % draw selection lines
            p3 = getappdata(main, 'p3');
            p4 = getappdata(main, 'p4');
            p1 = getappdata(main, 'p1');
            p2 = getappdata(main, 'p2');
            delete(p3)
            delete(p4)
            delete(p1)
            delete(p2)
            
            hold on
            pl1 = plot(ones(1,length(wavelengths{traceVal})).*pos(1),wavelengths{traceVal},'-', 'Color', [0.5 0.5 0.5], 'linewidth', 1);
            pl2 = plot(times{traceVal}, ones(1,length(times{traceVal})).*pos(2),'-', 'Color', [0.5 0.5 0.5], 'linewidth', 1);
            pl3 = plot(axSpect, img{traceValPrev}(:,posInd(1)), fliplr(wavelengths{traceValPrev}), 'color', [0.5,0.5,0.5]);
            pl4 = plot(axRet, times{traceValPrev}, img{traceValPrev}(s(1)-posInd(2),:), 'color', [0.5,0.5,0.5]);
            setappdata(main, 'pl1', pl1)
            setappdata(main, 'pl2', pl2)
            setappdata(main, 'pl3', pl3)
            setappdata(main, 'pl4', pl4)
        
            % hide TickLabels for trace-axes
            set(axRet,'XTickLabel','')
            set(axRet,'YTickLabel','')
            set(axSpect,'XTickLabel','')
            set(axSpect,'YTickLabel','')

            % set ticklength for all axes
            set(ax, 'TickLength',[0.015 0.015]);
            set(axRet,'TickLength',[0.015 0.015]);
            set(axSpect,'TickLength',[0.03 0.03]);

            % set axis-limits
            Ly = get(ax, 'YLim');
            Lx = get(ax, 'XLim');
            ylim(Ly)
            xlim(Lx)
        else
            pl1 = getappdata(main, 'pl1');
            pl2 = getappdata(main, 'pl2');
            pl3 = getappdata(main, 'pl3');
            pl4 = getappdata(main, 'pl4');
            delete(pl1)
            delete(pl2)
            delete(pl3)
            delete(pl4)
        end
    end


    function fn_save(~,~)
        
        % home directory
        if ispc
            home_dir = getenv('USERPROFILE');
        else
            home_dir = getenv('HOME');
        end
        
        traceName = get(select_trace, 'String');
        traceVal = get(select_trace, 'Value');
        
        savepathname = uigetdir(sprintf('%s/Desktop', home_dir), 'Save As');
        if savepathname == 0
            return
        end
        
        % change display options for saving
        set(defineArea, 'visible', 'off')
        set(manualCrosshair, 'visible', 'off')
        set(lockingPos, 'visible', 'off')
        set(select_trace, 'visible', 'off')
        set(infoBox, 'visible', 'off')
        
        fontsize = get(ax, 'FontSize');
        cb = getappdata(main, 'cb');
        p3 = getappdata(main, 'p3');
        p4 = getappdata(main, 'p4');
        set(ax, 'FontSize', 15, 'linewidth', 1)
        set(axSpect, 'linewidth', 1)
        set(axRet, 'linewidth', 1)
        set(cb, 'linewidth', 1)
        
        %set(main, 'papersize', [19 10], 'paperposition', [0.5 0.8 18.5 9.5])
        filename = traceName{traceVal}(1:end-4);
        try
            %print('-dpdf',sprintf('%s/hplc_chromatogram.pdf', savepathname));
            %print('-dpng', sprintf('%s/%s.png', savepathname, filename), '-r600');
            exportgraphics(main, sprintf('%s/%s.png', savepathname, filename), "Resolution", 600)
        catch
            set(infoBox, 'String', 'printing failed - close the currently opened output-pdf file')
            
            % restoring default display settings
            set(defineArea, 'visible', 'on')
            set(manualCrosshair, 'visible', 'on')
            set(lockingPos, 'visible', 'on')
            set(select_trace, 'visible', 'on')
            set(infoBox, 'visible', 'on')
            
            set(ax, 'FontSize', fontsize, 'linewidth', 0.5)
            set(axSpect, 'linewidth', 0.5)
            set(axRet, 'linewidth', 0.5)
            set(cb, 'linewidth', 0.5)
            return
        end
        
        % restoring default display settings
        set(defineArea, 'visible', 'on')
        set(manualCrosshair, 'visible', 'on')
        set(lockingPos, 'visible', 'on')
        set(select_trace, 'visible', 'on')
        set(infoBox, 'visible', 'on')
        
        set(ax, 'FontSize', fontsize, 'linewidth', 0.5)
        set(axSpect, 'linewidth', 0.5)
        set(axRet, 'linewidth', 0.5)
        set(cb, 'linewidth', 0.5)
        
        set(infoBox, 'String', 'spectrum successfully saved...')
    end


    function fn_options(~,~)
        % create subfigure
        figure('name', 'Options', 'Position',[550 450 300 170],...
            'menubar', 'none', 'NumberTitle', 'off', 'resize', 'off');
        
        hp = uipanel('Title','File format', 'Position',[0.05 0.05 0.9 0.9]);
        
        % get variables
        delimiter = getappdata(main, 'delimiter');
        time_col = getappdata(main, 'time_col');
        wavelength_col_fromTo = getappdata(main, 'wavelength_col_fromTo');
        wavelength_fromTo = getappdata(main, 'wavelength_fromTo');
        row_fromTo = getappdata(main, 'row_fromTo');
        tick_manual = getappdata(main, 'tick_manual');
        
        if tick_manual == 1 
            on_off = 'on';
        else
            on_off = 'off'; 
        end
        
        % delimiter options
        uicontrol(hp,'Style','text',...
            'String','delimiter:',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.025,0.8,0.25,0.15]);        
        ui_delimiter = uicontrol(hp,'Style','edit',...
            'String',delimiter,...
            'HorizontalAlignment', 'center',...
            'units','norm', 'pos',[0.39,0.82,0.075,0.15],...
            'Callback',@choose_delim); 
        
        % time column options
        uicontrol(hp,'Style','text',...
            'String','time column:',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.025,0.60,0.25,0.15]); 
        ui_time_col = uicontrol(hp,'Style','edit',...
            'String',time_col,...
            'HorizontalAlignment', 'center',...
            'units','norm', 'pos',[0.39,0.62,0.075,0.15],...
            'Callback',@choose_time_col); 
        
        % numeric rows options
        uicontrol(hp,'Style','text',...
            'String','numeric rows:',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.025,0.40,0.4,0.15]); 
        ui_row_start = uicontrol(hp,'Style','edit',...
            'String',row_fromTo{1},...
            'HorizontalAlignment', 'center',...
            'Enable', on_off,...
            'units','norm', 'pos',[0.39,0.42,0.125,0.15],...
            'Callback',@choose_row_start);
        uicontrol(hp,'Style','text',...
            'String','to',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.55,0.4,0.05,0.15]);
        ui_row_end = uicontrol(hp,'Style','edit',...
            'String',row_fromTo{2},...
            'HorizontalAlignment', 'center',...
            'Enable', on_off,...
            'units','norm', 'pos',[0.63,0.42,0.125,0.15],...
            'Callback',@choose_row_end);
        
        % wavelengths columns options
        uicontrol(hp,'Style','text',...
            'String','wavelength cols.:',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.025,0.2,0.4,0.15]); 
        ui_wave_col_start = uicontrol(hp,'Style','edit',...
            'String',wavelength_col_fromTo{1},...
            'HorizontalAlignment', 'center',...
            'units','norm', 'pos',[0.39,0.22,0.125,0.15],...
            'Callback',@choose_wave_col_start);
        uicontrol(hp,'Style','text',...
            'String','to',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.55,0.2,0.05,0.15]);
        ui_wave_col_end = uicontrol(hp,'Style','edit',...
            'String',wavelength_col_fromTo{2},...
            'HorizontalAlignment', 'center',...
            'units','norm', 'pos',[0.63,0.22,0.125,0.15],...
            'Callback',@choose_wave_col_end);
        
        
        % wavelengths options
        uicontrol(hp,'Style','text',...
            'String','wavelength:',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.025,0.02,0.4,0.15]); 
        ui_wave_start = uicontrol(hp,'Style','edit',...
            'String',wavelength_fromTo{1},...
            'HorizontalAlignment', 'center',...
            'Enable', on_off,...
            'units','norm', 'pos',[0.39,0.04,0.125,0.15],...
            'Callback',@choose_wave_start);
        uicontrol(hp,'Style','text',...
            'String','to',...
            'HorizontalAlignment', 'left',...
            'units','norm', 'pos',[0.55,0.02,0.05,0.15]);
        ui_wave_end = uicontrol(hp,'Style','edit',...
            'String',wavelength_fromTo{2},...
            'HorizontalAlignment', 'center',...
            'Enable', on_off,...
            'units','norm', 'pos',[0.63,0.04,0.125,0.15],...
            'Callback',@choose_wave_end);
        
       % manual import checkbox 
       ui_tick_manual = uicontrol(hp,'Style','checkbox',...
            'Value',tick_manual,...
            'units','norm', 'pos',[0.63,0.62,0.1,0.15],...
            'Callback',@choose_tick_manual);
       uicontrol(hp,'Style','text',...
            'String','manual import',...
            'units','norm', 'pos',[0.69,0.6,0.3,0.15]);        
        
        
        function choose_delim(~,~)
            delimiter = get(ui_delimiter, 'String');
            if ~contains(['\t', ',', ';', ' '], delimiter)
                set(ui_delimiter, 'background', [0.90, 0.56, 0.54])
                set(infoBox, 'String', 'Unrecognized delimiter')
            else
                setappdata(main, 'delimiter', delimiter);
                set(ui_delimiter, 'background', 'white')
            end
        end
        
        function choose_time_col(~,~)
            time_col = get(ui_time_col, 'String');
            if ~isnan(str2double(time_col))
                setappdata(main, 'time_col', time_col);
                set(ui_time_col, 'background', 'white')
            else
                set(ui_time_col, 'background', [0.90, 0.56, 0.54]);
                set(infoBox, 'String', 'Time column value is not numeric')
            end
        end
        
        function choose_row_start(~,~)
            row_start = get(ui_row_start, 'String');
            if ~isnan(str2double(row_start))
                row_fromTo{1} = row_start;
                setappdata(main, 'row_fromTo', row_fromTo);
                set(ui_row_start, 'background', 'white')
            else
                set(ui_row_start, 'background', [0.90, 0.56, 0.54]);
                set(infoBox, 'String', 'Row start value is not numeric')
            end
        end
        
        function choose_row_end(~,~)
            row_end = get(ui_row_end, 'String');
            if ~isnan(str2double(row_end)) || strcmp(row_end, 'end')
                row_fromTo{2} = row_end;
                setappdata(main, 'row_fromTo', row_fromTo);
                set(ui_row_end, 'background', 'white')
            else
                set(ui_row_end, 'background', [0.90, 0.56, 0.54]);
                set(infoBox, 'String', 'Row end value is not numeric nor "end"')
            end
        end
        
        function choose_wave_col_start(~,~)
            wave_col_start = get(ui_wave_col_start, 'String');
            if ~isnan(str2double(wave_col_start))
                wavelength_col_fromTo{1} = wave_col_start;
                setappdata(main, 'wavelength_col_fromTo', wavelength_col_fromTo);
                set(ui_wave_col_start, 'background', 'white')
            else
                set(ui_wave_col_start, 'background', [0.90, 0.56, 0.54]);
                set(infoBox, 'String', 'Wavelength start column value is not numeric')
            end
        end
        
        function choose_wave_col_end(~,~)
            wave_col_end = get(ui_wave_col_end, 'String');
            if ~isnan(str2double(wave_col_end)) || strcmp(wave_col_end, 'end')
                wavelength_col_fromTo{2} = wave_col_end;
                setappdata(main, 'wavelength_col_fromTo', wavelength_col_fromTo);
                set(ui_wave_col_end, 'background', 'white')
            else
                set(ui_wave_col_end, 'background', [0.90, 0.56, 0.54]);
                set(infoBox, 'String', 'Wavelength end column value is not numeric nor "end"')
            end
        end
        
        function choose_wave_start(~,~)
            wave_start = get(ui_wave_start, 'String');
            if ~isnan(str2double(wave_start))
                wavelength_fromTo{1} = wave_start;
                setappdata(main, 'wavelength_fromTo', wavelength_fromTo);
                set(ui_wave_start, 'background', 'white')
            else
                set(ui_wave_start, 'background', [0.90, 0.56, 0.54]);
                set(infoBox, 'String', 'Wavelength start value is not numeric')
            end
        end
        
        function choose_wave_end(~,~)
            wave_end = get(ui_wave_end, 'String');
            if ~isnan(str2double(wave_end))
                wavelength_fromTo{2} = wave_end;
                setappdata(main, 'wavelength_fromTo', wavelength_fromTo);
                set(ui_wave_end, 'background', 'white')
            else
                set(ui_wave_end, 'background', [0.90, 0.56, 0.54]);
                set(infoBox, 'String', 'Wavelength end value is not numeric nor "end"')
            end
        end
    
        function choose_tick_manual(~,~)
            tick_manual = get(ui_tick_manual, 'Value');
            setappdata(main, 'tick_manual', tick_manual);
            if tick_manual
                set(ui_row_start, 'Enable', 'on')
                set(ui_row_end, 'Enable', 'on')
                set(ui_wave_start, 'Enable', 'on')
                set(ui_wave_end, 'Enable', 'on')
            else
                set(ui_row_start, 'Enable', 'off')
                set(ui_row_end, 'Enable', 'off')
                set(ui_wave_start, 'Enable', 'off')
                set(ui_wave_end, 'Enable', 'off')
            end
        end
    end


    function fn_cutSpect(~,~)
        % create subfigure
        cutFig = figure('name', 'Crop Chromatogram', 'Position',[550 450 300 150],...
            'menubar', 'none', 'NumberTitle', 'off', 'resize', 'off');
        setappdata(main, 'cutFig', cutFig)
        
        % pushbutton for defining the evaluation subrange
        uicontrol('Style','pushbutton',...
            'String','export',...
            'Position',[115,15,70,25],...
            'Callback',@exportIT);
        
        % get variables
        wavelengths = getappdata(main, 'wavelengths');
        times = getappdata(main, 'times');
        traceVal = get(select_trace, 'Value');
        
        
        % sliders and textboxes
        selectWaveStart = uicontrol('Style','slider',...
            'Value', min(wavelengths{traceVal}),...
            'min', min(wavelengths{traceVal}),...
            'max', max(wavelengths{traceVal}),...
            'sliderstep', [1/(max(wavelengths{traceVal})-min(wavelengths{traceVal})) , 10/(max(wavelengths{traceVal})-min(wavelengths{traceVal}))],...
            'Position',[30,120,85,15],...
            'Callback',@chooseWaveStart);
        
        waveStringStart = uicontrol('Style','text',...
            'String',sprintf('start wavelength: %d nm', min(wavelengths{traceVal})),...
            'HorizontalAlignment', 'left', ...
            'Position',[135,120,200,15]);
        
        function chooseWaveStart(~,~)
            waveValStart = get(selectWaveStart, 'Value');
            set(waveStringStart, 'String', sprintf('start wavelength: %0.0f nm', waveValStart))
        end
        
        
        selectWaveEnd = uicontrol('Style','slider',...
            'Value', max(wavelengths{traceVal}),...
            'min', min(wavelengths{traceVal}),...
            'max', max(wavelengths{traceVal}),...
            'sliderstep', [1/(max(wavelengths{traceVal})-min(wavelengths{traceVal})) , 10/(max(wavelengths{traceVal})-min(wavelengths{traceVal}))],...
            'Position',[30,100,85,15],...
            'Callback',@chooseWaveEnd);
        
        waveStringEnd = uicontrol('Style','text',...
            'String',sprintf('end wavelength: %0.0f nm', max(wavelengths{traceVal})),...
            'HorizontalAlignment', 'left',...
            'Position',[135,100,200,15]);
        
        function chooseWaveEnd(~,~)
            waveValEnd = get(selectWaveEnd, 'Value');
            set(waveStringEnd, 'String', sprintf('end wavelength: %0.0f nm', waveValEnd))
        end
        
        
        selectTimeStart = uicontrol('Style','slider',...
            'Value', min(times{traceVal}(1)),...
            'min', min(times{traceVal}),...
            'max', max(times{traceVal}),...
            'sliderstep', [0.1/(max(times{traceVal})-min(times{traceVal})) , 1/(max(times{traceVal})-min(times{traceVal}))],...
            'Position',[30,70,85,15],...
            'Callback',@chooseTimeStart);
        
        timeStringStart = uicontrol('Style','text',...
            'String',sprintf('start time: %0.1f min', min(times{traceVal})),...
            'HorizontalAlignment', 'left',...
            'Position',[135,70,200,15]);
        
        function chooseTimeStart(~,~)
            timeValStart = get(selectTimeStart, 'Value');
            set(timeStringStart, 'String', sprintf('start time: %0.1f min', timeValStart))
        end
        
        
        selectTimeEnd = uicontrol('Style','slider',...
            'Value', max(times{traceVal}),...
            'min', min(times{traceVal}),...
            'max', max(times{traceVal}),...
            'sliderstep', [0.1/(max(times{traceVal})-min(times{traceVal})) , 1/(max(times{traceVal})-min(times{traceVal}))],...
            'Position',[30,50,85,15],...
            'Callback',@chooseTimeEnd);
        
        timeStringEnd = uicontrol('Style','text',...
            'String',sprintf('end time: %0.1f min', max(times{traceVal})),...
            'HorizontalAlignment', 'left',...
            'Position',[135,50,200,15]);
        
        function chooseTimeEnd(~,~)
            timeValEnd = get(selectTimeEnd, 'Value');
            set(timeStringEnd, 'String', sprintf('end time: %0.1f min', timeValEnd))
        end
        
        
        function exportIT(~,~)
            % export the cutted chromatogram to a text file
            % get variables
            data2 = getappdata(main, 'data2');
            head = getappdata(main, 'head');
            wavelengths = getappdata(main, 'wavelengths');
            times = getappdata(main, 'times');
            time_col = getappdata(main, 'time_col');
            wavelength_col_fromTo = getappdata(main, 'wavelength_col_fromTo');

            % home directory
            if ispc
                home_dir = getenv('USERPROFILE');
            else
                home_dir = getenv('HOME');
            end
            savepathname = uigetdir(sprintf('%s/Desktop', home_dir), 'Save As');
            if savepathname == 0
                return
            end
            
            % open text file in binary mode (wt correspond to text mode)
            filename = getappdata(main, 'filename');
            fid = fopen(sprintf('%s/%s_cut.txt', savepathname, filename{traceVal}(1:end-4)), 'w');
            
            % get strings of head
            head3 = [head{traceVal}{:}];
            head4 = head3(~cellfun('isempty',head3));
            
            % get lower and upper wavelengths and times
            waveStart = get(selectWaveStart, 'Value');
            waveEnd = get(selectWaveEnd, 'Value');
            timeStart = get(selectTimeStart, 'Value');
            timeEnd = get(selectTimeEnd, 'Value');
            
            % define indices for wavelenghts and times
            [~, w1] = min(abs(wavelengths{traceVal}-waveStart));
            [~, w2] = min(abs(wavelengths{traceVal}-waveEnd));
            [~, v1] = min(abs(times{traceVal}-timeStart));
            [~, v2] = min(abs(times{traceVal}-timeEnd));
            
            
            % extract subrange of wavelengths, the header and the original data
            wave = wavelengths{traceVal}(w1:w2);
            waveString = textscan(num2str(wave),'%s');
            headOut = [head4(str2double(time_col):str2double(wavelength_col_fromTo)-1) waveString{:}'];
            dataOut = [data2{traceVal}(v1:v2,str2double(time_col):str2double(wavelength_col_fromTo)-1) data2{traceVal}(v1:v2,w1:w2)]';
            
            % define format specifier
            n = size(dataOut,1);
            head_ID = repmat('%s\t',1,n);
            data_ID = repmat('%f\t',1,n);
            head_ID(end) = 'n'; data_ID(end) = 'n';
            
            % write to text file
            fprintf(fid, head_ID, headOut{:});
            fprintf(fid, data_ID, dataOut);
            fclose(fid);
            
            % close the subfigure and update in infoBox
            cutFig = getappdata(main, 'cutFig');
            close(cutFig)
            set(infoBox, 'String', 'cropped chromatogram successfully exported...')
            
        end
        
        
    end


    function fn_extractTraceSpect(~,~)
        % get variables
        pos = getappdata(main, 'pos');
        wavelengths = getappdata(main, 'wavelengths');
        times = getappdata(main, 'times');
        img = getappdata(main, 'img');
        traceVal = get(select_trace, 'Value');
        s = size(img{traceVal});

        % get position index
        posInd = pos2Ind(pos);
        
        % home directory
            if ispc
                home_dir = getenv('USERPROFILE');
            else
                home_dir = getenv('HOME');
            end
            savepathname = uigetdir(sprintf('%s/Desktop', home_dir), 'Save As');
            if savepathname == 0
                return
            end
            
        % open text file in binary mode (wt correspond to text mode)
        filename = getappdata(main, 'filename');
        
        spectrum = fliplr(img{traceVal}(:,posInd(1))');
        spectrum_norm = (spectrum-min(spectrum))/(max(spectrum)-min(spectrum));
        fid = fopen(sprintf('%s/%s_spectrum_%0.2fmin.txt', savepathname, filename{traceVal}(1:end-4), pos(1)), 'w');
        fprintf(fid, '%s\t%s\t%s\n', 'wavelength (nm)', 'intensity', 'normalized intensity');
        fprintf(fid, '%f\t%f\t%f\n', [wavelengths{traceVal}; spectrum; spectrum_norm]);
        fclose(fid);
        
        trace = img{traceVal}(s(1)-posInd(2),:);
        trace_norm = (trace-min(trace))/(max(trace)-min(trace));
        fid = fopen(sprintf('%s/%s_trace_%0.0fnm.txt', savepathname, filename{traceVal}(1:end-4), pos(2)), 'w');
        fprintf(fid, '%s\t%s\t%s\n', 'time (min)', 'intensity', 'normalized intensity');
        fprintf(fid, '%f\t%f\t%f\n', [times{traceVal}'; trace; trace_norm]);
        fclose(fid);
        
        set(infoBox, 'String', 'Trace and spectrum successfully extracted...')

    end


    function fn_helpMe(~,~)
        set(infoBox, 'String', 'Getting help...')
        % create HTML file
        path = mfilename('fullpath');
        [pathstr, ~, ~] = fileparts(path);
        try
            htmlFile = [pathstr filesep 'README.html'];
            url = ['file:///',htmlFile];
            web(url)
        catch
            set(infoBox, 'String', 'Help file cannot be found...')
        end
    end

    function fn_About(~,~)
        % create subfigure for About
        figure('name', 'About HPLC2Spect', 'Position',[550 450 300 150],...
            'menubar', 'none', 'NumberTitle', 'off', 'resize', 'off');
        path = mfilename('fullpath');
        [pathstr, ~, ~] = fileparts(path);
        try
            [icon, ~, alpha] = imread([pathstr filesep 'docs/hplc2spect_icon.png']);
            image(icon, 'alphaData', alpha)
            set(gca, 'visible', 'off', 'Position', [0.015, 0.35, 0.5 0.5])
            axis equal
        catch
        end
        % define text and imageboxes
        uicontrol('Style','text',...
            'String','HPLC2Spect, v.2.0',...
            'FontWeight', 'bold',...
            'HorizontalAlignment', 'left',...
            'Units', 'normalized',...
            'Position',[0.1, 0.15, 0.75 0.15]);
        uicontrol('Style','text',...
            'String','(C) Fabio Steffen, 2017-2019',...
            'HorizontalAlignment', 'left',...
            'Units', 'normalized',...
            'Position',[0.1, 0.05, 0.75 0.15]);
        uicontrol('Style','text',...
            'String','HPLC2Spect is a program to view and process 2D HPLC chromatograms',...
            'HorizontalAlignment', 'left',...
            'Units', 'normalized',...
            'Position',[0.51, 0.35, 0.40 0.5]);
    end


end