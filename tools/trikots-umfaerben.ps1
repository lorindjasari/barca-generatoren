# Legt die echten Trikot-Designs (Vorlagen in tools\trikot-vorlagen) auf die Heim-Fotos
# aus player-photos.js  ->  player-photos-away.js / player-photos-third.js
# Aufruf:  powershell -ExecutionPolicy Bypass -File tools\trikots-umfaerben.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Keepers = @('joan-garcia','szczesny','livakovic')   # Torwart-Trikots bleiben unverändert

# Vorlagen: yV = Höhe der vorderen Kragen-Oberkante in der Mitte (Pixel im Vorlagenbild), Kragenfarbe
$Kits = @{
  away  = @{ file = 'away-original.png';  yV = 104; collar = @(18,18,20) }
  third = @{ file = 'third-original.png'; yV = 95;  collar = @(10,26,64) }
}

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Drawing2D; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class KitMap {
  static void Hsv(int r,int g,int b,out double h,out double s,out double v){
    double R=r/255.0,G=g/255.0,B=b/255.0, mx=Math.Max(R,Math.Max(G,B)), mn=Math.Min(R,Math.Min(G,B)), d=mx-mn;
    v=mx; s=mx==0?0:d/mx; h=0; if(d==0) return;
    if(mx==R) h=60*(((G-B)/d)%6); else if(mx==G) h=60*((B-R)/d+2); else h=60*((R-G)/d+4);
    if(h<0) h+=360;
  }
  static double Clamp(double x,double a,double b){ return x<a?a:(x>b?b:x); }
  static double Smooth(double a,double b,double x){ double t=Clamp((x-a)/(b-a),0,1); return t*t*(3-2*t); }
  static byte B8(double x){ return (byte)Clamp(Math.Round(x),0,255); }
  static byte[] Bytes(Bitmap bmp){
    BitmapData d=bmp.LockBits(new Rectangle(0,0,bmp.Width,bmp.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    byte[] px=new byte[bmp.Width*bmp.Height*4]; Marshal.Copy(d.Scan0,px,0,px.Length); bmp.UnlockBits(d); return px;
  }
  static Bitmap FromBytes(byte[] px,int w,int h){
    Bitmap bmp=new Bitmap(w,h,PixelFormat.Format32bppArgb);
    BitmapData d=bmp.LockBits(new Rectangle(0,0,w,h),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
    Marshal.Copy(px,0,d.Scan0,px.Length); bmp.UnlockBits(d); return bmp;
  }

  // ---- Vorlage freistellen: Hintergrund vom Rand her entfernen ----
  public static double TexXc, TexW;
  public static Bitmap CutOut(Bitmap src, string kit){
    int w=src.Width,h=src.Height;
    Bitmap tmp=new Bitmap(w,h,PixelFormat.Format32bppArgb); using(Graphics g=Graphics.FromImage(tmp)){ g.DrawImage(src,0,0,w,h); }
    byte[] px=Bytes(tmp); tmp.Dispose();
    bool[] bg=new bool[w*h]; double hh,ss,vv;
    Queue<int> q=new Queue<int>();
    Func<int,bool> isBg = k => { int i=k*4;
      if(kit=="away") return Math.Min(px[i],Math.Min(px[i+1],px[i+2]))>222;
      Hsv(px[i+2],px[i+1],px[i],out hh,out ss,out vv); return ss<0.13 && vv>0.55; };
    for(int x=0;x<w;x++){ q.Enqueue(x); q.Enqueue((h-1)*w+x); }
    for(int y=0;y<h;y++){ q.Enqueue(y*w); q.Enqueue(y*w+w-1); }
    while(q.Count>0){ int k=q.Dequeue(); if(bg[k]||!isBg(k)) continue; bg[k]=true; int x=k%w,y=k/w;
      if(x>0) q.Enqueue(k-1); if(x<w-1) q.Enqueue(k+1); if(y>0) q.Enqueue(k-w); if(y<h-1) q.Enqueue(k+w); }
    // Rand um 2 Pixel abtragen (heller Saum)
    for(int pass=0;pass<2;pass++){ bool[] nb=(bool[])bg.Clone();
      for(int y=1;y<h-1;y++) for(int x=1;x<w-1;x++){ int k=y*w+x; if(!bg[k] && (bg[k-1]||bg[k+1]||bg[k-w]||bg[k+w])) nb[k]=true; }
      bg=nb; }
    for(int k=0;k<w*h;k++) if(bg[k]) px[k*4+3]=0;
    // Rumpfbreite und Mitte (Zeilen unterhalb der Ärmel)
    List<double> ws=new List<double>(), cs=new List<double>();
    for(int y=(int)(h*0.58);y<(int)(h*0.70);y++){ int l=-1,r=-1; for(int x=0;x<w;x++) if(px[(y*w+x)*4+3]>0){ if(l<0) l=x; r=x; }
      if(l>=0){ ws.Add(r-l); cs.Add((l+r)/2.0); } }
    ws.Sort(); cs.Sort(); TexW=ws[ws.Count/2]; TexXc=cs[cs.Count/2];
    return FromBytes(px,w,h);
  }

  // ---- Trikot-Design auf ein Spielerfoto legen ----
  public static Bitmap Apply(Bitmap src, Bitmap tex, double txc, double tW, double tyV, string kit, int cR,int cG,int cB){
    int w=src.Width,h=src.Height;
    Bitmap tmp=new Bitmap(w,h,PixelFormat.Format32bppArgb); using(Graphics g=Graphics.FromImage(tmp)){ g.DrawImage(src,0,0,w,h); }
    byte[] px=Bytes(tmp); tmp.Dispose();
    byte[] cls=new byte[w*h]; int[] rowCount=new int[h]; double hh,ss,vv;
    // 1) Trikotfarben erkennen (Blau über Violett bis Granatrot; Hauttöne ausgeschlossen)
    for(int y=0;y<h;y++) for(int x=0;x<w;x++){
      int i=(y*w+x)*4; if(px[i+3]<40) continue;
      Hsv(px[i+2],px[i+1],px[i],out hh,out ss,out vv);
      bool jersey = (hh>=205 && hh<356 && ss>0.42 && vv>0.10) || ((hh>=356 || hh<8) && ss>0.75 && vv>0.25);
      if(jersey){ if(px[i+3]>=150){ cls[y*w+x]=1; rowCount[y]++; } else cls[y*w+x]=9; }
    }
    for(int y=0;y<h;y++) for(int x=0;x<w;x++){
      if(cls[y*w+x]!=9) continue; bool near=false;
      for(int dy=-2;dy<=2&&!near;dy++) for(int dx=-2;dx<=2;dx++){ int yy=y+dy,xx=x+dx; if(yy<0||yy>=h||xx<0||xx>=w) continue; if(cls[yy*w+xx]==1){ near=true; break; } }
      cls[y*w+x]=(byte)(near?8:0);
    }
    for(int k2=0;k2<cls.Length;k2++) if(cls[k2]==8) cls[k2]=1;
    // 2) Oberkante des Trikots (erste breite Trikot-Zeile unterhalb des Kopfes)
    int top=-1; for(int y=(int)(h*0.28);y<h;y++) if(rowCount[y]>=w*0.20){ top=y; break; }
    if(top<0) return FromBytes(px,w,h);
    int safeTop=Math.Max(0,top-4);
    double[] Lum=new double[w*h]; double sumL=0; int nL=0;
    for(int y=0;y<h;y++) for(int x=0;x<w;x++){
      int k=y*w+x, i=k*4;
      Lum[k]=(0.299*px[i+2]+0.587*px[i+1]+0.114*px[i])/255.0;
      if(y<safeTop){ cls[k]=0; continue; }
      if(px[i+3]<40) continue;
      if(cls[k]==1){ sumL+=Lum[k]; nL++; }
      else { Hsv(px[i+2],px[i+1],px[i],out hh,out ss,out vv);
        bool skin = hh<=50 && ss>0.15;
        }
    }
    if(nL<200) return FromBytes(px,w,h);
    double mAll=sumL/nL;
    // 3) Eingeschlossene Flächen (Wappen, Sponsor, Nike-Logo) gehören zum Trikot -> werden überdeckt
    bool[] outside=new bool[w*h]; Queue<int> q=new Queue<int>();
    // Start nur von oben und von den Seiten: der untere Bildrand zählt als geschlossen (angeschnittene Logos)
    for(int x=0;x<w;x++){ q.Enqueue(x); }
    for(int y=0;y<h;y++){ q.Enqueue(y*w); q.Enqueue(y*w+w-1); }
    while(q.Count>0){ int k=q.Dequeue(); if(outside[k]||cls[k]==1||cls[k]==3) continue; outside[k]=true; int x=k%w,y=k/w;
      if(x>0) q.Enqueue(k-1); if(x<w-1) q.Enqueue(k+1); if(y>0) q.Enqueue(k-w); if(y<h-1) q.Enqueue(k+w); }
    // unterste Zeile: Logos, die vom Bildrand angeschnitten sind, ebenfalls füllen, wenn links und rechts Trikot liegt
    for(int k=0;k<w*h;k++) if(cls[k]==0 && !outside[k] && px[k*4+3]>40) cls[k]=5;
    // 4) Geometrie: Rumpfmitte, Rumpfbreite (untere Zeilen), Kragenpunkt
    double sx=0; int sn=0; for(int k=0;k<w*h;k++) if(cls[k]!=0){ sx+=k%w; sn++; }
    int cx0=(int)(sx/sn);
    List<double> ws=new List<double>(), cs=new List<double>();
    for(int y=(int)(h*0.84);y<(int)(h*0.97);y++){
      if(cls[y*w+cx0]==0) continue; int l=cx0,r=cx0,gap=0;
      for(int x=cx0-1;x>=0;x--){ if(cls[y*w+x]!=0){ l=x; gap=0; } else if(++gap>2) break; } gap=0;
      for(int x=cx0+1;x<w;x++){ if(cls[y*w+x]!=0){ r=x; gap=0; } else if(++gap>2) break; }
      ws.Add(r-l); cs.Add((l+r)/2.0); }
    double Wp=w*0.42, xc=cx0;
    if(ws.Count>3){ ws.Sort(); cs.Sort(); Wp=Clamp(ws[ws.Count/2],w*0.30,w*0.60); xc=cs[cs.Count/2]; }
    List<int> tops=new List<int>();
    for(int x=(int)xc-2;x<=(int)xc+2;x++) for(int y=safeTop;y<h;y++) if(cls[y*w+x]!=0){ tops.Add(y); break; }
    tops.Sort(); double yV=tops.Count>0?tops[tops.Count/2]:top;
    // Unterhalb der Ärmel gibt es außerhalb der Rumpfbreite kein Trikot mehr -> Unterarme bleiben unberührt
    for(int y=0;y<h;y++) for(int x=0;x<w;x++){ int k=y*w+x;
      if(cls[k]!=0 && Math.Abs(x-xc)>Wp*0.55 && (y-yV)>Wp*0.80) cls[k]=0; }
    // 5) Vorlage auf Spielergröße skalieren
    double sc=Wp*1.04/tW;
    int tw=(int)Math.Ceiling(tex.Width*sc), th=(int)Math.Ceiling(tex.Height*sc);
    Bitmap st=new Bitmap(tw,th,PixelFormat.Format32bppArgb);
    using(Graphics g=Graphics.FromImage(st)){ g.InterpolationMode=InterpolationMode.HighQualityBicubic; g.PixelOffsetMode=PixelOffsetMode.HighQuality; g.DrawImage(tex,new Rectangle(0,0,tw,th),0,0,tex.Width,tex.Height,GraphicsUnit.Pixel); }
    byte[] tp=Bytes(st); st.Dispose();
    double txcS=txc*sc, tyVS=tyV*sc, halfT=tW*sc/2;
    // Ärmelfarben (Median) links/rechts aus der Vorlage
    double[][] sleeve=new double[2][];
    for(int side=0;side<2;side++){
      List<double[]> cols=new List<double[]>();
      for(int y=(int)(tyVS+0.1*halfT*2);y<(int)(tyVS+0.6*halfT*2)&&y<th;y++) for(int x=0;x<tw;x++){
        bool sel = side==0 ? x<txcS-1.24*halfT : x>txcS+1.24*halfT; if(!sel) continue; int i=(y*tw+x)*4; if(tp[i+3]<200) continue;
        cols.Add(new double[]{0.299*tp[i+2]+0.587*tp[i+1]+0.114*tp[i],tp[i+2],tp[i+1],tp[i]}); }
      if(cols.Count==0){ sleeve[side]=new double[]{cR,cG,cB}; continue; }
      cols.Sort((a,b)=>a[0].CompareTo(b[0])); double[] m=cols[(int)(cols.Count*0.6)]; sleeve[side]=new double[]{m[1],m[2],m[3]};
    }
    // Summentabellen für die Schattierung (nur ursprüngliche Trikot-Pixel)
    int W1=w+1; double[] iL=new double[W1*(h+1)]; double[] iN=new double[W1*(h+1)];
    for(int y=0;y<h;y++){ double rl=0,rn=0; for(int x=0;x<w;x++){ int k=y*w+x; if(cls[k]==1){ rl+=Lum[k]; rn+=1; }
      iL[(y+1)*W1+x+1]=iL[y*W1+x+1]+rl; iN[(y+1)*W1+x+1]=iN[y*W1+x+1]+rn; } }
    // Faltenwurf: Helligkeit relativ zum Spalten-Mittel (rechnet die senkrechten Streifen heraus),
    // danach weichgezeichnet, damit keine feinen Längsstreifen entstehen
    double[] det=new double[w*h];
    for(int y=safeTop;y<h;y++) for(int x=0;x<w;x++){
      int k=y*w+x; if(cls[k]!=1){ det[k]=1; continue; }
      int a0=Math.Max(0,x-1), a1=Math.Min(w,x+2), b0=Math.Max(0,y-24), b1=Math.Min(h,y+25);
      double cn=iN[b1*W1+a1]-iN[b0*W1+a1]-iN[b1*W1+a0]+iN[b0*W1+a0];
      double cm=cn>6 ? (iL[b1*W1+a1]-iL[b0*W1+a1]-iL[b1*W1+a0]+iL[b0*W1+a0])/cn : mAll;
      det[k]=Clamp(Lum[k]/Math.Max(0.03,cm),0.72,1.28);
    }
    double[] iD=new double[W1*(h+1)]; double[] iM=new double[W1*(h+1)];
    for(int y=0;y<h;y++){ double rd=0,rm=0; for(int x=0;x<w;x++){ int k=y*w+x; if(cls[k]!=0){ rd+=det[k]; rm+=1; }
      iD[(y+1)*W1+x+1]=iD[y*W1+x+1]+rd; iM[(y+1)*W1+x+1]=iM[y*W1+x+1]+rm; } }
    byte[] outp=(byte[])px.Clone();
    double halfP=Wp/2;
    for(int y=safeTop;y<h;y++) for(int x=0;x<w;x++){
      int k=y*w+x, i=k*4; byte c=cls[k]; if(c==0) continue;
      double dx=x-xc, dy=y-yV, adx=Math.Abs(dx);
      // --- Farbe aus der Vorlage ---
      int tx=(int)Math.Round(txcS+dx), ty=(int)Math.Round(tyVS+dy);
      double r,g,b; bool have=false; r=g=b=0;
      if(tx>=0&&tx<tw&&ty>=0&&ty<th){ int ti=(ty*tw+tx)*4; if(tp[ti+3]>128){ r=tp[ti+2]; g=tp[ti+1]; b=tp[ti]; have=true; } }
      // oberhalb der vorderen Kragenkante (Innenseite des Nackens in der Vorlage) -> Kragenfarbe
      if(adx<80*sc && (tyVS+dy) < tyVS-0.30*adx+1){ r=cR; g=cG; b=cB; have=true; }
      // Ärmel/Schulter außerhalb der Rumpfbreite: einheitliche Ärmelfarbe, Bündchen am Ärmelende
      double[] sl=sleeve[dx<0?0:1];
      double sw=Smooth(halfP*0.98,halfP*1.08,adx);
      if(!have){ r=sl[0]; g=sl[1]; b=sl[2]; }
      else if(sw>0){ r=r+(sl[0]-r)*sw; g=g+(sl[1]-g)*sw; b=b+(sl[2]-b)*sw; }
      if(sw>0.5){ bool cuff=false;
        for(int y2=y+1;y2<=y+6&&y2<h;y2++){ int k2=y2*w+x; if(cls[k2]==0){ cuff = px[k2*4+3]>150; break; } }
        if(cuff){ r=cR; g=cG; b=cB; } }
      // --- Schattierung vom Originalfoto (Streifen herausgerechnet) ---
      int x0=Math.Max(0,x-30), x1=Math.Min(w,x+31), y0=Math.Max(0,y-30), y1=Math.Min(h,y+31);
      double bn=iN[y1*W1+x1]-iN[y0*W1+x1]-iN[y1*W1+x0]+iN[y0*W1+x0];
      double bm=bn>20 ? (iL[y1*W1+x1]-iL[y0*W1+x1]-iL[y1*W1+x0]+iL[y0*W1+x0])/bn : mAll;
      double s=Math.Pow(Clamp(bm/mAll,0.5,1.6),0.55);
      // weichgezeichneter Faltenwurf (7x5-Fenster: quer breiter, damit Längsstreifen verschwinden)
      x0=Math.Max(0,x-3); x1=Math.Min(w,x+4); y0=Math.Max(0,y-2); y1=Math.Min(h,y+3);
      double dm=iM[y1*W1+x1]-iM[y0*W1+x1]-iM[y1*W1+x0]+iM[y0*W1+x0];
      if(dm>0) s*=(iD[y1*W1+x1]-iD[y0*W1+x1]-iD[y1*W1+x0]+iD[y0*W1+x0])/dm;
      s=1+0.9*(s-1);
      if(kit=="away"){ s=Clamp(s,0.45,1.7); double hi=s>1?(s-1)*36:0; r=r*s+hi; g=g*s+hi; b=b*s+hi; }
      else { s=Clamp(s,0.5,1.2); r*=s; g*=s; b*=s; }
      outp[i+2]=B8(r); outp[i+1]=B8(g); outp[i]=B8(b);
    }
    return FromBytes(outp,w,h);
  }
}
'@

function To-DataUrl([System.Drawing.Bitmap]$bmp) {
  $ms = New-Object IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $s = 'data:image/png;base64,' + [Convert]::ToBase64String($ms.ToArray()); $ms.Dispose(); $s
}

# Vorlagen freistellen
$Tex = @{}
foreach ($kit in 'away','third') {
  $k = $Kits[$kit]
  $srcT = New-Object System.Drawing.Bitmap (Join-Path $Root "tools\trikot-vorlagen\$($k.file)")
  $cut = [KitMap]::CutOut($srcT, $kit); $srcT.Dispose()
  $cut.Save((Join-Path $Root "tools\trikot-vorlagen\$kit-freigestellt.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $Tex[$kit] = @{ bmp = $cut; xc = [KitMap]::TexXc; W = [KitMap]::TexW }
  Write-Host ("Vorlage {0}: Mitte {1}, Rumpfbreite {2}" -f $kit, $Tex[$kit].xc, $Tex[$kit].W)
}

$js = [IO.File]::ReadAllText((Join-Path $Root 'player-photos.js'))
$found = [regex]::Matches($js, "'([\w-]+)':\s*'data:image/png;base64,([^']+)'")
if ($found.Count -eq 0) { throw 'Keine Fotos in player-photos.js gefunden.' }

$out = @{ away = @(); third = @() }
$sheet = New-Object System.Drawing.Bitmap (160*9), (160*[Math]::Ceiling($found.Count/3))
$sg = [System.Drawing.Graphics]::FromImage($sheet); $sg.Clear([System.Drawing.Color]::FromArgb(20,30,80)); $sg.InterpolationMode='HighQualityBicubic'
$zoomIds = 'pedri','yamal','kounde','adeyemi'
$zoom = New-Object System.Drawing.Bitmap 960, (320*$zoomIds.Count)
$zg = [System.Drawing.Graphics]::FromImage($zoom); $zg.Clear([System.Drawing.Color]::FromArgb(20,30,80))
$n = 0
foreach ($m in $found) {
  $id = $m.Groups[1].Value
  $ms = New-Object IO.MemoryStream (,[Convert]::FromBase64String($m.Groups[2].Value))
  $src = [System.Drawing.Bitmap]::FromStream($ms)
  $col = ($n % 3) * 480; $row = [Math]::Floor($n / 3) * 160
  $sg.DrawImage($src, $col, $row, 160, 160)
  $zi = [Array]::IndexOf($zoomIds, $id); if ($zi -ge 0) { $zg.DrawImage($src, 0, 320*$zi, 320, 320) }
  $j = 1
  foreach ($kit in 'away','third') {
    if ($Keepers -contains $id) { $bmp = New-Object System.Drawing.Bitmap $src }
    else { $k = $Kits[$kit]; $t = $Tex[$kit]; $bmp = [KitMap]::Apply($src, $t.bmp, $t.xc, $t.W, $k.yV, $kit, $k.collar[0], $k.collar[1], $k.collar[2]) }
    $out[$kit] += "  '$id': '$(To-DataUrl $bmp)'"
    $sg.DrawImage($bmp, $col + 160*$j, $row, 160, 160)
    if ($zi -ge 0) { $zg.DrawImage($bmp, 320*$j, 320*$zi, 320, 320) }
    $j++; $bmp.Dispose()
  }
  $src.Dispose(); $ms.Dispose(); $n++
}
$sg.Dispose(); $zg.Dispose()
$sheet.Save((Join-Path $Root 'tools\vorschau-trikots.png'), [System.Drawing.Imaging.ImageFormat]::Png); $sheet.Dispose()
$zoom.Save((Join-Path $Root 'tools\vorschau-trikots-gross.png'), [System.Drawing.Imaging.ImageFormat]::Png); $zoom.Dispose()

$names = @{ away = 'Auswaertstrikot'; third = '3. Trikot' }
foreach ($kit in 'away','third') {
  $txt = "// Automatisch erzeugt von tools\trikots-umfaerben.ps1: Heim-Fotos mit aufgelegtem Trikot-Design ($($names[$kit]))`nwindow.PLAYER_PHOTOS = window.PLAYER_PHOTOS || {};`nwindow.PLAYER_PHOTOS.$kit = {`n" + ($out[$kit] -join ",`n") + "`n};`n"
  [IO.File]::WriteAllText((Join-Path $Root "player-photos-$kit.js"), $txt, (New-Object Text.UTF8Encoding $false))
}
Write-Host "Fertig: $n Spieler, je 2 Trikot-Varianten. Vorschau: tools\vorschau-trikots.png"
