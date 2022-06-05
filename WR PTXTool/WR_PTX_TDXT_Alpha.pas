unit WR_PTX_TDXT_Alpha;
interface
uses
  Math, KromUtils;

procedure DXT_A_Encode(R1,R2,R3,R4:Pointer; out OutDat:int64; out RMS:single);
procedure DXT_A_Decode(aInDat: Pointer; out aOutDat: array of Byte);

implementation

procedure DXT_A_Encode(R1,R2,R3,R4:Pointer; out OutDat:int64; out RMS:single);
const
  Tolerate=2; //Which color-value should be treated as non pure black/white, '2' fits just fine
var
  i: integer; //counter
  InputColor: array[1..16]of byte; //Input color
  TestColor: array[1..16]of byte; //Will store reference test color to compute RMS error
  ColorMin: byte;
  ColorMax: byte;
  im:array[1..16]of byte;
  Trial: array[1..2]of record
    Dat: int64;
    tRMS: single;
  end;
begin
  FillChar(im, SizeOf(im), #0);
  FillChar(Trial, SizeOf(Trial), #0);
  for i:=0 to 3 do InputColor[i+1]:=byte(Char(Pointer((Integer(R1)+i*4))^));
  for i:=0 to 3 do InputColor[i+1+4]:=byte(Char(Pointer((Integer(R2)+i*4))^));
  for i:=0 to 3 do InputColor[i+1+8]:=byte(Char(Pointer((Integer(R3)+i*4))^));
  for i:=0 to 3 do InputColor[i+1+12]:=byte(Char(Pointer((Integer(R4)+i*4))^));

  //Find min-max colors
  ColorMin := 255;
  ColorMax := 0;
  for i:=1 to 8 do ColorMin := min(ColorMin,InputColor[i*2-1],InputColor[i*2]);
  for i:=1 to 8 do ColorMax := max(ColorMax,InputColor[i*2-1],InputColor[i*2]);

//If there's same color over the block, then use archive-friendly output
//Col for first byte and zero for other
if ColorMin = ColorMax then
begin
  OutDat := ColorMin; //Rest of In64 is filled with zeroes
end else
begin
  with Trial[1] do
  begin

    for i := 1 to 16 do
    begin
      if InputColor[i]-ColorMin<>0 then //Don't divide by zero
        im[i] := round(7/((ColorMax-ColorMin)/(InputColor[i]-ColorMin)))  //0..7
      else
        im[i] := 0;
      im[i] := 7-im[i] + 1;
      if im[i] = 1 then im[i]:=0;
      if im[i] = 8 then im[i]:=1;
    end;

    Dat := ColorMax + (ColorMin shl 8); //Max goes first
    for i := 1 to 16 do
      Dat := Dat + int64( int64(im[i] AND $07) shl ( 16 + (i-1)*3 ) );
    DXT_A_Decode(@Dat, TestColor);
    tRMS := 0;
    for i := 1 to 16 do tRMS := tRMS + sqr(InputColor[i]-TestColor[i]);
  end;

  with Trial[2] do
  begin
    FillChar(im,SizeOf(im),#0); //reset
    ColorMin := 255 - Tolerate;
    ColorMax := Tolerate;
    for i:=1 to 16 do if InputColor[i] >= Tolerate       then ColorMin := Math.min(ColorMin, InputColor[i]);
    for i:=1 to 16 do if InputColor[i] <= (255-Tolerate) then ColorMax := Math.max(ColorMax, InputColor[i]);

    for i:=1 to 16 do begin
      if InputColor[i]<=(ColorMin div 2) then im[i]:=6 else
      if InputColor[i]>=(ColorMax div 2) then im[i]:=7 else
      if InputColor[i]<=ColorMin then im[i]:=0 else
      if InputColor[i]>=ColorMax then im[i]:=1 else
        begin
          im[i] := round(5/((ColorMax-ColorMin)/(InputColor[i]-ColorMin)))+1;  //0..5
          if im[i]=1 then im[i]:=0;
          if im[i]=6 then im[i]:=1;
        end;
    end;

    Dat := ColorMin + (ColorMax shl 8);
    for i := 1 to 16 do
    Dat := Dat + int64( int64(im[i] AND $07) shl ( 16 + (i-1)*3 ) );
    tRMS := 0;
    DXT_A_Decode(@Dat, TestColor);
    for i := 1 to 16 do tRMS := tRMS + sqr(InputColor[i]-TestColor[i]);
  end;

  //Choose least error-result and take it
  if Trial[1].tRMS<Trial[2].tRMS then begin
    RMS    := RMS + Trial[1].tRMS;
    OutDat := Trial[1].Dat;
  end else begin
    RMS    := RMS + Trial[2].tRMS;
    OutDat := Trial[2].Dat;
  end;
end;
end;


procedure DXT_A_Decode(aInDat: Pointer; out aOutDat: array of Byte);
var
  I, x: Byte;
  colorMin, colorMax, T: Byte;
  d: Int64;
begin
  d := Int64(aInDat^); //cast all 8 bytes into one int64 value
  colorMin := d and $FF;
  colorMax := (d shr 8) and $FF;
  d := d shr 16;

  for I := 0 to 15 do
  begin
    T := 0;
    x := d shr (I * 3) and $7; //Consequently pick up 3 adjustment bits
    if x = 0 then
      T := colorMin
    else
    if x = 1 then
      T := colorMax
    else

    if colorMin < colorMax then
      // Linear interpolation + min&max
      case x of
        2: T := Round((4*colorMin + 1*colorMax) / 5);
        3: T := Round((3*colorMin + 2*colorMax) / 5);
        4: T := Round((2*colorMin + 3*colorMax) / 5);
        5: T := Round((1*colorMin + 4*colorMax) / 5);
        6: T := 0;
        7: T := 255;
      end
    else
      // Linear interpolation x=2..7
      T := round(((8-x)*colorMin+(x-1)*colorMax)/7);

    aOutDat[I] := T; //0..15
  end;
end;


end.
