function [ output_args ] = TestOnlineRecognizer(  )
%TESTONLINERECOGNIZER Summary of this function goes here
%   Detailed explanation goes here

global LettersDataStructure; 
TestSetFolder = 'C:\OCRData\GeneratedWords';
LettersDataStructure = load('C:\OCRData\LettersFeatures\LettersDS');

clc;
correctRec = 0;
correctSeg = 0;
count = 0;
TestSetWordsFolderList = dir(TestSetFolder);
for i = 3:length(TestSetWordsFolderList)
    current_object = TestSetWordsFolderList(i);
    IsFile=~[current_object.isdir];
    FileName = current_object.name;
    FileNameSize = size(FileName);
    LastCharacter = FileNameSize(2);
    if (IsFile==1 && FileName(LastCharacter)=='m')
        sequence = dlmread([TestSetFolder,'\',FileName]);
        disp(' ')
        disp(['Word:  ',FileName])
        RecState = SimulateOnlineRecognizer( sequence );
        [CorrectNumLetters, CorrectRecognition] = correctRecognition(RecState,strrep(FileName, '.m', ''));
        
        %Statistics
        count=count+1;
        if (CorrectRecognition==true)
            correctRec = correctRec+1;
        end
        if (CorrectNumLetters==true)
            correctSeg = correctSeg+1;
        end
    end
end

RecognitionRate = correctSeg/count*100
SegmentationRate = correctRec/count*100
end


function [CorrectNumLetters, CorrectRecognition] = correctRecognition(RecState,Word)
CorrectRecognition=true;
CorrectNumLetters=true;

if (RecState.LCCPI~=size(Word))
    CorrectNumLetters = false;
    CorrectRecognition = false;
    return;
end
for i=1:RecState.LCCPI
    LCCP =  RecState.CriticalCPs(i);
    CurrCan = LCCP.Candidates(:,1);
    wasRecognized = false;
    for j=1:size(CurrCan,1)
        if (strcmp(CurrCan{j}{1},Word(i)))
            wasRecognized = true;
        end
    end
    if (wasRecognized==false)
        CorrectRecognition = false;
        return;
    end
end
end

