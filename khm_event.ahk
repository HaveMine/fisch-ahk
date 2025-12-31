#Requires AutoHotkey v2



class OCR {
    static IID_IRandomAccessStream := "{905A0FE1-BC53-11DF-8C49-001E4FC686DA}"
         , IID_IPicture            := "{7BF80980-BF32-101A-8BBB-00AA00300CAB}"
         , IID_IAsyncInfo          := "{00000036-0000-0000-C000-000000000046}"
         , IID_IAsyncOperation_OcrResult        := "{c7d7118e-ae36-59c0-ac76-7badee711c8b}"
         , IID_IAsyncOperation_SoftwareBitmap   := "{c4a10980-714b-5501-8da2-dbdacce70f73}"
         , IID_IAsyncOperation_BitmapDecoder    := "{aa94d8e9-caef-53f6-823d-91b6e8340510}"
         , Vtbl_GetDecoder := {bmp:6, jpg:7, jpeg:7, png:8, tiff:9, gif:10, jpegxr:11, ico:12}
         , PerformanceMode := 0

    class IBase {
        __New(ptr?) {
            if IsSet(ptr) && !ptr
                throw ValueError('Invalid pointer')
            this.DefineProp("ptr", {Value:ptr ?? 0})
        }
        __Delete() => this.ptr ? ObjRelease(this.ptr) : 0
    }

    static __New() {
        this.prototype.__OCR := this
        this.IBase.prototype.__OCR := this
        this.OCRLine.base := this.IBase, this.OCRLine.prototype.base := this.IBase.prototype
        this.OCRWord.base := this.IBase, this.OCRWord.prototype.base := this.IBase.prototype
        this.LanguageFactory := this.CreateClass("Windows.Globalization.Language", "{9B0252AC-0C27-44F8-B792-9793FB66C63E}")
        this.SoftwareBitmapFactory := this.CreateClass("Windows.Graphics.Imaging.SoftwareBitmap", "{c99feb69-2d62-4d47-a6b3-4fdb6a07fdf8}")
        this.BitmapTransform := this.CreateClass("Windows.Graphics.Imaging.BitmapTransform")
        this.BitmapDecoderStatics := this.CreateClass("Windows.Graphics.Imaging.BitmapDecoder", "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}")
        this.BitmapEncoderStatics := this.CreateClass("Windows.Graphics.Imaging.BitmapEncoder", "{a74356a7-a4e4-4eb9-8e40-564de7e1ccb2}")
        this.SoftwareBitmapStatics := this.CreateClass("Windows.Graphics.Imaging.SoftwareBitmap", "{df0385db-672f-4a9d-806e-c2442f343e86}")
        this.OcrEngineStatics := this.CreateClass("Windows.Media.Ocr.OcrEngine", "{5BFFA85A-3384-3540-9940-699120D428A8}")
        ComCall(6, this.OcrEngineStatics, "uint*", &MaxImageDimension:=0)
        this.MaxImageDimension := MaxImageDimension
        DllCall("Dwmapi\DwmIsCompositionEnabled", "Int*", &compositionEnabled:=0)
        this.CAPTUREBLT := compositionEnabled ? 0 : 0x40000000
        this.GrayScaleMCode := this.MCode((A_PtrSize = 4) 
        ? "2,x86:VVdWU4PsCIt0JCiLVCQki0QkIMHuAok0JIXSD4SDAAAAhcB0f408tQAAAAAx9ol8JASLfCQcjRyHMf+NdCYAkItEJByNDLiNtCYAAAAAZpCLEYPBBInQD7buwegQae1OAgAAD7bAacAsAQAAAegPtuqB4gAAAP9r7W4B6MHoConFCcLB4AjB5RAJ6gnQiUH8Odl1vIPGAQM8JANcJAQ5dCQkdZyDxAgxwFteX13D" 
        : "2,x64:QVZVV1ZTRInOSYnLQYnSRYnGwe4CRYXAdHJFMclFMcCF0nRoDx9AAESJyg8fRAAAidCDwgFJjQyDizmJ+In7wegQD7bvD7bAae1OAgAAacAsAQAAAehAD7bvgecAAAD/a+1uAejB6AqJxQnHweAIweUQCe8Jx4k5RDnSdbNBg8ABQQHxQQHyRTnGdZwxwFteX11BXsM=")
        this.InvertColorsMCode := this.MCode((A_PtrSize = 4)
        ? "2,x86:VVdWU4PsCIt8JCiLVCQki0QkIMHvAok8JIXSdF+FwHRbwecCMe2JfCQEi3wkHI00hzH/jXQmAJCLRCQcjQyokIsRg8EEidCJ04Hi/wAA//fQ99OA8v8lAAD/AIHjAP8AAAnYCdCJQfw58XXUg8cBAywkA3QkBDl8JCR1vIPECDHAW15fXcM="
        : "2,x64:VVdWU0SJz0iJy0GJ00SJxsHvAkWFwHRbRTHJRTHAhdJ0UWYPH0QAAESJyQ8fRAAAiciDwQFMjRSDQYsSidCJ1YHi/wAA//fQ99WA8v8lAAD/AIHlAP8AAAnoBdBBiQJBOct1zEGDwAFBAflBAftEOcZ1tTHAW15fXcM=")
    }

    __New(RandomAccessStreamOrSoftwareBitmap, lang := "FirstFromAvailableLanguages", transform := 1, decoder := "") {
        local SoftwareBitmap := 0, RandomAccessStream := 0, width, height, x, y, w, h, __OCR := this.__OCR, scale, grayscale, invertcolors
        __OCR.__ExtractTransformParameters(RandomAccessStreamOrSoftwareBitmap, &transform)
        scale := transform.scale, grayscale := transform.grayscale, invertcolors := transform.invertcolors, rotate := transform.rotate, flip := transform.flip
        __OCR.__ExtractNamedParameters(RandomAccessStreamOrSoftwareBitmap, "x", &x, "y", &y, "w", &w, "h", &h, "lang", &lang, "decoder", &decoder, "RandomAccessStream", &RandomAccessStreamOrSoftwareBitmap, "RAS", &RandomAccessStreamOrSoftwareBitmap, "SoftwareBitmap", &RandomAccessStreamOrSoftwareBitmap)
        __OCR.LoadLanguage(lang)

        try SoftwareBitmap := ComObjQuery(RandomAccessStreamOrSoftwareBitmap, "{689e0708-7eef-483f-963f-da938818e073}")
        if SoftwareBitmap {
            ComCall(8, SoftwareBitmap, "uint*", &width:=0)
            ComCall(9, SoftwareBitmap, "uint*", &height:=0)
            this.ImageWidth := width, this.ImageHeight := height
            if (Floor(width*scale) > __OCR.MaxImageDimension) or (Floor(height*scale) > __OCR.MaxImageDimension)
               throw ValueError("Image is too big")
            if scale != 1 || IsSet(x) || rotate || flip
                SoftwareBitmap := __OCR.TransformSoftwareBitmap(SoftwareBitmap, &width, &height, scale, rotate, flip, x?, y?, w?, h?)
            goto SoftwareBitmapCommon
        }
        RandomAccessStream := RandomAccessStreamOrSoftwareBitmap

        if decoder {
            ComCall(__OCR.Vtbl_GetDecoder.%decoder%, __OCR.BitmapDecoderStatics, "ptr", DecoderGUID:=Buffer(16))
            ComCall(15, __OCR.BitmapDecoderStatics, "ptr", DecoderGUID, "ptr", RandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        } else
            ComCall(14, __OCR.BitmapDecoderStatics, "ptr", RandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        __OCR.WaitForAsync(&BitmapDecoder)

        BitmapFrame := ComObjQuery(BitmapDecoder, "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")
        ComCall(12, BitmapFrame, "uint*", &width:=0)
        ComCall(13, BitmapFrame, "uint*", &height:=0)
        if (width > __OCR.MaxImageDimension) or (height > __OCR.MaxImageDimension)
           throw ValueError("Image is too big")

        BitmapFrameWithSoftwareBitmap := ComObjQuery(BitmapDecoder, "{FE287C9A-420C-4963-87AD-691436E08383}")
       if !IsSet(x) && (width < 40 || height < 40 || scale != 1) {
            scale := scale = 1 ? 40.0 / Min(width, height) : scale, this.ImageWidth := Floor(width*scale), this.ImageHeight := Floor(height*scale)
            ComCall(7, __OCR.BitmapTransform, "int", this.ImageWidth)
            ComCall(9, __OCR.BitmapTransform, "int", this.ImageHeight)
            ComCall(8, BitmapFrame, "uint*", &BitmapPixelFormat:=0)
            ComCall(9, BitmapFrame, "uint*", &BitmapAlphaMode:=0)
            ComCall(8, BitmapFrameWithSoftwareBitmap, "uint", BitmapPixelFormat, "uint", BitmapAlphaMode, "ptr", __OCR.BitmapTransform, "uint", IgnoreExifOrientation := 0, "uint", DoNotColorManage := 0, "ptr*", SoftwareBitmap:=ComValue(13,0))
        } else {
            this.ImageWidth := width, this.ImageHeight := height
            ComCall(6, BitmapFrameWithSoftwareBitmap, "ptr*", SoftwareBitmap:=ComValue(13,0))
        }
        __OCR.WaitForAsync(&SoftwareBitmap)
        if IsSet(x) || rotate || flip
            SoftwareBitmap := __OCR.TransformSoftwareBitmap(SoftwareBitmap, &width, &height, scale, rotate, flip, x?, y?, w?, h?)

        SoftwareBitmapCommon:

        if (grayscale || invertcolors) {
            ComCall(15, SoftwareBitmap, "int", 2, "ptr*", BitmapBuffer := ComValue(13,0))
            MemoryBuffer := ComObjQuery(BitmapBuffer, "{fbc4dd2a-245b-11e4-af98-689423260cf8}")
            ComCall(6, MemoryBuffer, "ptr*", MemoryBufferReference := ComValue(13,0))
            BufferByteAccess := ComObjQuery(MemoryBufferReference, "{5b0d3235-4dba-4d44-865e-8f1d0e4fd04d}")
            ComCall(3, BufferByteAccess, "ptr*", &SoftwareBitmapByteBuffer:=0, "uint*", &BufferSize:=0)

            if invertcolors
                DllCall(__OCR.InvertColorsMCode, "ptr", SoftwareBitmapByteBuffer, "uint", width, "uint", height, "uint", (width*4+3) // 4 * 4, "cdecl uint")
            
            if grayscale
                DllCall(__OCR.GrayScaleMCode, "ptr", SoftwareBitmapByteBuffer, "uint", width, "uint", height, "uint", (width*4+3) // 4 * 4, "cdecl uint")
            
            BufferByteAccess := "", MemoryBufferReference := "", MemoryBuffer := "", BitmapBuffer := ""
        }

        ComCall(6, __OCR.OcrEngine, "ptr", SoftwareBitmap, "ptr*", OcrResult:=ComValue(13,0))
        __OCR.WaitForAsync(&OcrResult)
        this.ptr := OcrResult.ptr, ObjAddRef(OcrResult.ptr)

        if RandomAccessStream is __OCR.IBase
            __OCR.CloseIClosable(RandomAccessStream)
        if SoftwareBitmap is __OCR.IBase
            __OCR.CloseIClosable(SoftwareBitmap)

        if scale != 1
            __OCR.NormalizeCoordinates(this, scale)
    }

    __Delete() => this.ptr ? ObjRelease(this.ptr) : 0

    Text {
        get {
            ComCall(8, this, "ptr*", &hAllText:=0)
            buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hAllText, "uint*", &length:=0, "ptr")
            this.DefineProp("Text", {Value:StrGet(buf, "UTF-16")})
            this.__OCR.DeleteHString(hAllText)
            return this.Text
        }
    }

    Lines {
        get {
            ComCall(6, this, "ptr*", LinesList:=this.__OCR.IBase())
            ComCall(7, LinesList, "int*", &count:=0)
            lines := []
            loop count {
                ComCall(6, LinesList, "int", A_Index-1, "ptr*", OcrLine:=this.__OCR.OCRLine())               
                lines.Push(OcrLine)
            }
            this.DefineProp("Lines", {Value:lines})
            return lines
        }
    }

    Words {
        get {
            local words := [], line, word
            for line in this.Lines
                for word in line.Words
                    words.Push(word)
            this.DefineProp("Words", {Value:words})
            return words
        }
    }

    class OCRLine {
        Text {
            get {
                ComCall(7, this, "ptr*", &hText:=0)
                buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
                text := StrGet(buf, "UTF-16")
                this.__OCR.DeleteHString(hText)
                this.DefineProp("Text", {Value:text})
                return text
            }
        }

        Words {
            get {
                ComCall(6, this, "ptr*", WordsList:=this.__OCR.IBase())
                ComCall(7, WordsList, "int*", &WordsCount:=0)
                words := []
                loop WordsCount {
                   ComCall(6, WordsList, "int", A_Index-1, "ptr*", OcrWord:=this.__OCR.OCRWord())
                   words.Push(OcrWord)
                }
                this.DefineProp("Words", {Value:words})
                return words
            }
        }

        BoundingRect {
            get {
                local rect := this.__OCR.WordsBoundingRect(this.Words*)
                return {x:rect.X, y:rect.Y, w:rect.W, h:rect.H}
            }
        }
    }

    class OCRWord {
        Text {
            get {
                ComCall(7, this, "ptr*", &hText:=0)
                buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
                text := StrGet(buf, "UTF-16")
                this.__OCR.DeleteHString(hText)
                this.DefineProp("Text", {Value:text})
                return text
            }
        }

        BoundingRect {
            get {
                ComCall(6, this, "ptr", RECT := Buffer(16, 0))
                return {x:Integer(NumGet(RECT, 0, "float")), y:Integer(NumGet(RECT, 4, "float")), w:Integer(NumGet(RECT, 8, "float")), h:Integer(NumGet(RECT, 12, "float"))}
            }
        }
    }

    static FromDesktop(lang?, transform:=1, monitor?) {
        if IsSet(lang) {
            this.__ExtractTransformParameters(lang, &transform)
            lang := lang.HasProp("lang") ? lang : unset
        }
        MonitorGet(monitor?, &Left, &Top, &Right, &Bottom)
        return this.FromRect(Left, Top, Right-Left, Bottom-Top, lang?, transform)
    }

    static LoadLanguage(lang:="FirstFromAvailableLanguages") {
        local hString, Language:=this.IBase(), OcrEngine:=this.IBase()
        if this.HasOwnProp("CurrentLanguage") && this.HasOwnProp("OcrEngine") && this.CurrentLanguage = lang
            return
        if (lang = "FirstFromAvailableLanguages")
            ComCall(10, this.OcrEngineStatics, "ptr*", OcrEngine)
        else {
            hString := this.CreateHString(lang)
            , ComCall(6, this.LanguageFactory, "ptr", hString, "ptr*", Language)
            , this.DeleteHString(hString)
            , ComCall(9, this.OcrEngineStatics, "ptr", Language, "ptr*", OcrEngine)
        }
        if (OcrEngine.ptr = 0) {
            msgbox "Failed to load OCR language", "Error", "0x40030"
            exitapp
        }
        this.OcrEngine := OcrEngine, this.CurrentLanguage := lang
    }

    static WordsBoundingRect(words*) {
        if !words.Length
            throw ValueError("Need at least one argument")
        local X1 := 100000000, Y1 := 100000000, X2 := -100000000, Y2 := -100000000, word
        for word in words {
            X1 := Min(word.x, X1), Y1 := Min(word.y, Y1), X2 := Max(word.x+word.w, X2), Y2 := Max(word.y+word.h, Y2)
        }
        return {X:X1, Y:Y1, W:X2-X1, H:Y2-Y1, X2:X2, Y2:Y2}
    }

    static TransformSoftwareBitmap(SoftwareBitmap, &sbW, &sbH, scale:=1, rotate:=0, flip:=0, X?, Y?, W?, H?) {
        InMemoryRandomAccessStream := this.SoftwareBitmapToRandomAccessStream(SoftwareBitmap)
        ComCall(this.Vtbl_GetDecoder.png, this.BitmapDecoderStatics, "ptr", DecoderGUID:=Buffer(16))
        ComCall(15, this.BitmapDecoderStatics, "ptr", DecoderGUID, "ptr", InMemoryRandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        this.WaitForAsync(&BitmapDecoder)
        BitmapFrameWithSoftwareBitmap := ComObjQuery(BitmapDecoder, "{FE287C9A-420C-4963-87AD-691436E08383}")
        BitmapFrame := ComObjQuery(BitmapDecoder, "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")
        BitmapTransform := this.CreateClass("Windows.Graphics.Imaging.BitmapTransform")
        local sW := Floor(sbW*scale), sH := Floor(sbH*scale), intermediate
        if scale != 1 {
            ComCall(7, BitmapTransform, "uint", sW)
            ComCall(9, BitmapTransform, "uint", sH)
        }
        if rotate {
            ComCall(15, BitmapTransform, "uint", rotate//90)
            if rotate = 90 || rotate = 270
                intermediate := sW, sW := sH, sH := intermediate
        }
        if flip
            ComCall(13, BitmapTransform, "uint", flip)
        if IsSet(X) {
            bounds := Buffer(16,0), NumPut("int", Floor(X*scale), "int", Floor(Y*scale), "int", Floor(Min(sbW-X, W)*scale), "int", Floor(Min(sbH-Y, H)*scale), bounds)
            ComCall(17, BitmapTransform, "ptr", bounds)
        }
        ComCall(8, BitmapFrame, "uint*", &BitmapPixelFormat:=0)
        ComCall(9, BitmapFrame, "uint*", &BitmapAlphaMode:=0)
        ComCall(8, BitmapFrameWithSoftwareBitmap, "uint", BitmapPixelFormat, "uint", BitmapAlphaMode, "ptr", BitmapTransform, "uint", IgnoreExifOrientation := 0, "uint", DoNotColorManage := 0, "ptr*", SoftwareBitmap:=ComValue(13,0))
        this.WaitForAsync(&SoftwareBitmap)
        this.CloseIClosable(InMemoryRandomAccessStream)
        sbW := sW, sbH := sH
        return SoftwareBitmap
    }

    static CreateHBitmap(X, Y, W, H, hWnd:=0, scale:=1) {
        local sW := Ceil(W*scale), sH := Ceil(H*scale), onlyClientArea := 0, mode := 2, HDC, obm, hbm, pdc, hbm2
        if hWnd {
            if IsObject(hWnd)
                onlyClientArea := hWnd.HasOwnProp("onlyClientArea") ? hWnd.onlyClientArea : onlyClientArea, mode := hWnd.HasOwnProp("mode") ? hWnd.mode : mode, hWnd := hWnd.hWnd
            HDC := DllCall("GetDCEx", "Ptr", hWnd, "Ptr", 0, "Int", 2|!onlyClientArea, "Ptr")
            if mode > 0 {
                PDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
                HBM := DllCall("CreateCompatibleBitmap", "Ptr", HDC, "Int", Max(40,X+W), "Int", Max(40,Y+H), "Ptr")
                , OBM := DllCall("SelectObject", "Ptr", PDC, "Ptr", HBM, "Ptr")
                , DllCall("PrintWindow", "Ptr", hWnd, "Ptr", PDC, "UInt", (mode=2?2:0)|!!onlyClientArea)
                if scale != 1 || X != 0 || Y != 0 {
                    PDC2 := DllCall("CreateCompatibleDC", "Ptr", PDC, "Ptr")
                    , HBM2 := DllCall("CreateCompatibleBitmap", "Ptr", PDC, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr")
                    , OBM2 := DllCall("SelectObject", "Ptr", PDC2, "Ptr", HBM2, "Ptr")
                    , PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
                    , DllCall("StretchBlt", "Ptr", PDC2, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", PDC, "Int", X, "Int", Y, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
                    , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
                    , DllCall("SelectObject", "Ptr", PDC2, "Ptr", obm2)
                    , DllCall("DeleteDC", "Ptr", PDC)
                    , DllCall("DeleteObject", "UPtr", HBM)
                    , hbm := hbm2, pdc := pdc2
                }
                DllCall("SelectObject", "Ptr", PDC, "Ptr", OBM)
                , DllCall("DeleteDC", "Ptr", HDC)
                , oHBM := this.IBase(HBM), oHBM.DC := PDC
                return oHBM.DefineProp("__Delete", {call:(this, *)=>(DllCall("DeleteObject", "Ptr", this), DllCall("DeleteDC", "Ptr", this.DC))})
            }
        } else {
            HDC := DllCall("GetDC", "Ptr", 0, "Ptr")
        }
        PDC := DllCall("CreateCompatibleDC", "Ptr", HDC, "Ptr")
        , HBM := DllCall("CreateCompatibleBitmap", "Ptr", HDC, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr")
        , OBM := DllCall("SelectObject", "Ptr", PDC, "Ptr", HBM, "Ptr")
        if sW < 40 || sH < 40
            DllCall("StretchBlt", "Ptr", PDC, "Int", 0, "Int", 0, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr", HDC, "Int", X, "Int", Y, "Int", 1, "Int", 1, "UInt", 0x00CC0020 | this.CAPTUREBLT)
        PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
        , DllCall("StretchBlt", "Ptr", PDC, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", HDC, "Int", X, "Int", Y, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
        , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
        , DllCall("SelectObject", "Ptr", PDC, "Ptr", OBM)
        , DllCall("DeleteDC", "Ptr", HDC)
        , oHBM := this.IBase(HBM), oHBM.DC := PDC
        return oHBM.DefineProp("__Delete", {call:(this, *)=>(DllCall("DeleteObject", "Ptr", this), DllCall("ReleaseDC", "Ptr", 0, "Ptr", this.DC))})
    }

    static HBitmapToSoftwareBitmap(hBitmap, hDC?, transform?) {
        local bi := Buffer(40, 0), W, H
        hDC := (hBitmap is OCR.IBase ? hBitmap.DC : (hDC ?? dhDC := DllCall("GetDC", "Ptr", 0, "UPtr")))
        NumPut("uint", 40, bi, 0)
        DllCall("GetDIBits", "ptr", hDC, "ptr", hBitmap, "uint", 0, "uint", 0, "ptr", 0, "ptr", bi, "uint", 0)
        W := NumGet(bi, 4, "int"), H := NumGet(bi, 8, "int")
        ComCall(7, this.SoftwareBitmapFactory, "int", 87, "int", W, "int", H, "int", 0, "ptr*", SoftwareBitmap := ComValue(13,0))
        ComCall(15, SoftwareBitmap, "int", 2, "ptr*", BitmapBuffer := ComValue(13,0))
        MemoryBuffer := ComObjQuery(BitmapBuffer, "{fbc4dd2a-245b-11e4-af98-689423260cf8}")
        ComCall(6, MemoryBuffer, "ptr*", MemoryBufferReference := ComValue(13,0))
        BufferByteAccess := ComObjQuery(MemoryBufferReference, "{5b0d3235-4dba-4d44-865e-8f1d0e4fd04d}")
        ComCall(3, BufferByteAccess, "ptr*", &SoftwareBitmapByteBuffer:=0, "uint*", &BufferSize:=0)
        NumPut("short", 32, "short", 0, bi, 14), NumPut("int", -H, bi, 8)
        DllCall("GetDIBits", "ptr", hDC, "ptr", hBitmap, "uint", 0, "uint", H, "ptr", SoftwareBitmapByteBuffer, "ptr", bi, "uint", 0)
        if IsSet(dhDC)
            DllCall("DeleteDC", "ptr", dhDC)
        BufferByteAccess := "", MemoryBufferReference := "", MemoryBuffer := "", BitmapBuffer := ""
        return SoftwareBitmap
    }

    static SoftwareBitmapToRandomAccessStream(SoftwareBitmap) {
        InMemoryRandomAccessStream := this.CreateClass("Windows.Storage.Streams.InMemoryRandomAccessStream")
        ComCall(8, this.BitmapEncoderStatics, "ptr", encoderId := Buffer(16, 0))
        ComCall(13, this.BitmapEncoderStatics, "ptr", encoderId, "ptr", InMemoryRandomAccessStream, "ptr*", BitmapEncoder:=ComValue(13,0))
        this.WaitForAsync(&BitmapEncoder)
        BitmapEncoderWithSoftwareBitmap := ComObjQuery(BitmapEncoder, "{686cd241-4330-4c77-ace4-0334968b1768}")
        ComCall(6, BitmapEncoderWithSoftwareBitmap, "ptr", SoftwareBitmap)
        ComCall(19, BitmapEncoder, "ptr*", asyncAction:=ComValue(13,0))
        this.WaitForAsync(&asyncAction)
        ComCall(11, InMemoryRandomAccessStream, "int64", 0)
        return InMemoryRandomAccessStream
    }

    static FromRect(x, y?, w?, h?, lang?, transform:=1) {
        this.__ExtractTransformParameters(x, &transform)
        this.__ExtractNamedParameters(x, "y", &y, "w", &w, "h", &h, "lang", &lang, "x", &x)
        local scale := transform.scale
            , hBitmap := this.CreateHBitmap(X, Y, W, H,, scale)
            , result := this(this.HBitmapToSoftwareBitmap(hBitmap,, transform), lang?)
        result.Relative := {Screen:{x:x, y:y, w:w, h:h}}
        return this.NormalizeCoordinates(result, scale)
    }

    static MCode(mcode) {
        static e := Map('1', 4, '2', 1), c := (A_PtrSize=8) ? "x64" : "x86"
        if (!regexmatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", &m))
          return
        if (!DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", 0, "uint*", &s := 0, "ptr", 0, "ptr", 0))
          return
        p := DllCall("GlobalAlloc", "uint", 0, "ptr", s, "ptr")
        if (c="x64")
          DllCall("VirtualProtect", "ptr", p, "ptr", s, "uint", 0x40, "uint*", &op := 0)
        if (DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", p, "uint*", &s, "ptr", 0, "ptr", 0))
          return p
        DllCall("GlobalFree", "ptr", p)
    }

    static CreateClass(str, interface?) {
        local hString := this.CreateHString(str), result
        if !IsSet(interface) {
            result := DllCall("Combase.dll\RoActivateInstance", "ptr", hString, "ptr*", cls:=this.IBase(), "uint")
        } else {
            GUID := this.CLSIDFromString(interface)
            result := DllCall("Combase.dll\RoGetActivationFactory", "ptr", hString, "ptr", GUID, "ptr*", cls:=this.IBase(), "uint")
        }
        if (result != 0)
            throw Error("Failed to create class")
        this.DeleteHString(hString)
        return cls
    }
    
    static CreateHString(str) => (DllCall("Combase.dll\WindowsCreateString", "wstr", str, "uint", StrLen(str), "ptr*", &hString:=0), hString)
    
    static DeleteHString(hString) => DllCall("Combase.dll\WindowsDeleteString", "ptr", hString)
    
    static WaitForAsync(&obj) {
        local AsyncInfo := ComObjQuery(obj, this.IID_IAsyncInfo), status
        Loop {
            ComCall(7, AsyncInfo, "uint*", &status:=0)
            if (status != 0) {
                if (status != 1) {
                    ComCall(8, ASyncInfo, "uint*", &ErrorCode:=0)
                    throw Error("Async operation failed")
                }
                break
            }
            Sleep this.PerformanceMode ? -1 : 1
        }
        ComCall(8, obj, "ptr*", ObjectResult:=this.IBase())
        obj := ObjectResult
    }

    static CloseIClosable(pClosable) {
        static IClosable := "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}"
        local Close := ComObjQuery(pClosable, IClosable)
        ComCall(6, Close)
    }

    static CLSIDFromString(IID) {
        local CLSID := Buffer(16), res
        if res := DllCall("ole32\CLSIDFromString", "WStr", IID, "Ptr", CLSID, "UInt")
           throw Error("CLSIDFromString failed")
        Return CLSID
    }

    static NormalizeCoordinates(result, scale) {
        local word
        if scale != 1 {
            for word in result.Words
                word.x := Integer(word.x / scale), word.y := Integer(word.y / scale), word.w := Integer(word.w / scale), word.h := Integer(word.h / scale), word.BoundingRect := {X:word.x, Y:word.y, W:word.w, H:word.h}
        }
        return result
    }

    static __ExtractNamedParameters(obj, params*) {
        local i := 0
        if !IsObject(obj) || Type(obj) != "Object"
            return 0
        Loop params.Length // 2 {
            name := params[++i], value := params[++i]
            if obj.HasProp(name)
                %value% := obj.%name%
        }
        return 1
    }

    static __ExtractTransformParameters(obj, &transform) {
        local scale := 1, grayscale := 0, invertcolors := 0, rotate := 0, flip := 0
        if IsObject(obj)
            this.__ExtractNamedParameters(obj, "scale", &scale, "grayscale", &grayscale, "invertcolors", &invertcolors, "rotate", &rotate, "flip", &flip, "transform", &transform)
        if IsObject(transform) {
            for prop in ["scale", "grayscale", "invertcolors", "rotate", "flip"]
                if !transform.HasProp(prop)
                    transform.%prop% := %prop%
        } else
            transform := {scale:scale, grayscale:grayscale, invertcolors:invertcolors, rotate:rotate, flip:flip}
        transform.flip := transform.flip = "y" ? 1 : transform.flip = "x" ? 2 : transform.flip
    }
}



global TextToDetect := []
global IsRunning := 0
global LogDisplay
global LogToggleButton
global LogCollapsed := 1
global OCRBoxX := 0, OCRBoxY := 0, OCRBoxW := A_ScreenWidth, OCRBoxH := A_ScreenHeight
global BoxDragging := 0, DragStartX := 0, DragStartY := 0
global StartButton
global DiscordWebhookUrl := ""  ; 
global SentItems := Map()  ; 

LoadDetectionList() {
    global TextToDetect
    listFile := A_ScriptDir "\list.txt"
    
    if !FileExist(listFile) {
        MsgBox "list.txt not found in script directory!", "Error", "0x40030"
        return
    }
    
    fileContent := FileRead(listFile)
    fileContent := StrReplace(fileContent, "`r`n", "`n")
    lines := StrSplit(fileContent, "`n")
    
    for line in lines {
        line := Trim(line)  ; Trim whitespace
        if (line != "") {
            TextToDetect.Push(line)
        }
    }
    
    UpdateLog("[INIT] Loaded " TextToDetect.Length " detection items from list.txt")
}

MyGUI := Gui("-DPIScale")
MyGUI.Opt("+AlwaysOnTop")
MyGUI.BackColor := "1E1E2E"
MyGUI.SetFont("s20 cWhite bold", "Segoe UI")

MyGUI.Add("Text",, "OCR Text Detector")
MyGUI.SetFont("s11 cWhite norm", "Segoe UI")
StartButton := MyGUI.Add("Button", "y+10 w250 h40", "Start Detection (F3)")
StartButton.OnEvent("Click", (*) => ToggleDetection())
MyGUI.Add("Button", "y+23 w250 h40", "Retake Box (F5)").OnEvent("Click", (*) => RetakeOCRBox())
MyGUI.Add("Button", "y+23 w250 h40", "Exit (F4)").OnEvent("Click", (*) => ExitApp())

MyGUI.SetFont("s20 cWhite bold", "Segoe UI")
MyGUI.Add("Text",, "Discord Webhook")

MyGUI.SetFont("s9 cWhite norm", "Segoe UI")
WebhookEdit := MyGUI.Add("Edit", "y+10 w600 h30 c000000", DiscordWebhookUrl)
MyGUI.SetFont("s11 cWhite", "Segoe UI")
MyGUI.Add("Button", "y+23 w250 h40", "Test Webhook").OnEvent("Click", (*) => TestWebhook(WebhookEdit.Value))
MyGUI.Add("Button", "y+23 w250 h40", "Save Webhook").OnEvent("Click", (*) => SaveWebhook(WebhookEdit.Value))

LogToggleButton := MyGUI.Add("Text", "w600 h30 +0x100 c3366FF", "> Detection Log")
LogToggleButton.SetFont("underline")
LogToggleButton.OnEvent("Click", (*) => ToggleLogDisplay())
MyGUI.SetFont("s10 c000000", "Segoe UI")
LogDisplay := MyGUI.Add("Edit", "w600 h350 Multi ReadOnly cBlack Hidden", "Log output:`n")
MyGUI.SetFont("s11 cWhite", "Segoe UI")
MyGUI.Show("w800 h900")
MyGUI.Title := "Khm Event"

LoadDetectionList()

f3::ToggleDetection
f4::ExitApp
f5::RetakeOCRBox

RetakeOCRBox() {
    global OCRBoxX, OCRBoxY, OCRBoxW, OCRBoxH
    
    message := "[" A_Now "] Setting OCR box... Drag the red box to your desired position and size, then press R"
    UpdateLog(message)
    
    BoxGUI := Gui("+ToolWindow +AlwaysOnTop -Caption +Resize -DPIScale")
    BoxGUI.BackColor := "FF0000"
    BoxGUI.Show("x100 y100 w600 h400")
    WinSetTransparent(120, BoxGUI.Hwnd)
    
    OnMessage("0x201", WM_LBUTTONDOWN)
    
    KeyWait "R", "D"
    
    OnMessage("0x201", WM_LBUTTONDOWN, 0)
    
    WinGetPos(&OCRBoxX, &OCRBoxY, &OCRBoxW, &OCRBoxH, BoxGUI.Hwnd)
    
    message := "[" A_Now "] OCR Box Set: X=" OCRBoxX " Y=" OCRBoxY " W=" OCRBoxW " H=" OCRBoxH
    UpdateLog(message)
    FileAppend(message "`n", "ocr_log.txt")
    
    BoxGUI.Destroy()
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd)
{
    PostMessage "0xA1", 2
}

ToggleDetection() {
    global IsRunning, LogDisplay, StartButton
    if (IsRunning) {
        IsRunning := 0
        SetTimer(CheckText, 0)
        message := "[" A_Now "] Detection STOPPED"
        FileAppend(message "`n", "ocr_log.txt")
        UpdateLog(message)
        StartButton.Text := "Start Detection (F3)"
    } else {
        IsRunning := 1
        message := "[" A_Now "] Detection STARTED"
        FileAppend(message "`n", "ocr_log.txt")
        UpdateLog(message)
        StartButton.Text := "Stop Detection (F3)"
        SetTimer(CheckText, 1000)
    }
}

CheckText() {
    global TextToDetect, LogDisplay, OCRBoxX, OCRBoxY, OCRBoxW, OCRBoxH, SentItems, DiscordWebhookUrl
    
    try {
        if (OCRBoxW > 100 && OCRBoxH > 100) {
            result := OCR.FromRect(OCRBoxX, OCRBoxY, OCRBoxW, OCRBoxH)
        } else {
            result := OCR.FromDesktop()
        }
        
        detectedText := result.Text
        
        for textItem in TextToDetect {
            searchText := Trim(textItem)
            if (searchText == "") {
                continue
            }
            
            if (InStr(detectedText, searchText, 1)) {
                currentTime := A_TickCount // 1000
                
                if (!SentItems.Has(searchText) || (currentTime - SentItems[searchText]) >= 900) {
                    message := "[" A_Now "] FOUND: " searchText
                    FileAppend(message "`n", "ocr_log.txt")
                    OutputDebugString(message)
                    UpdateLog(message)
                    
                    if (DiscordWebhookUrl != "YOUR_WEBHOOK_URL_HERE") {
                        SendDiscordWebhook(searchText)
                    }
                    
                    SentItems[searchText] := currentTime
                }
            }
        }
    } catch Error as err {
        UpdateLog("[ERROR] " err.What)
    }
}

SendDiscordWebhook(itemText) {
    global DiscordWebhookUrl
    
    try {
        payload := '{"content":"@everyone \n 🎉 **FOUND**: ' itemText '"}'
        
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", DiscordWebhookUrl, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(payload)
        
        if (http.Status == 204) {
            OutputDebugString("[DISCORD] Message sent for: " itemText)
        } else {
            OutputDebugString("[DISCORD ERROR] Status: " http.Status)
        }
    } catch Error as err {
        OutputDebugString("[DISCORD ERROR] " err.What)
    }
}

TestWebhook(webhookUrl) {
    global LogDisplay
    
    if (webhookUrl == "" || webhookUrl == "YOUR_WEBHOOK_URL_HERE") {
        UpdateLog("[ERROR] Webhook URL cannot be empty!")
        return
    }
    
    try {
        UpdateLog("[TEST] Sending test message to webhook...")
        
        payload := '{"content":"@everyone \n ✅ Webhook test successful!"}'
        
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", webhookUrl, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(payload)
        
        if (http.Status == 204) {
            UpdateLog("[SUCCESS] Webhook test successful! Message sent to Discord.")
            OutputDebugString("[DISCORD TEST] Success")
        } else {
            UpdateLog("[ERROR] Webhook test failed! Status: " http.Status)
            OutputDebugString("[DISCORD TEST] Failed - Status: " http.Status)
        }
    } catch Error as err {
        UpdateLog("[ERROR] " err.What)
        OutputDebugString("[DISCORD TEST ERROR] " err.What)
    }
}

SaveWebhook(webhookUrl) {
    global DiscordWebhookUrl, LogDisplay
    
    if (webhookUrl == "") {
        UpdateLog("[ERROR] Webhook URL cannot be empty!")
        return
    }
    
    DiscordWebhookUrl := webhookUrl
    UpdateLog("[SUCCESS] Webhook URL saved!")
}

UpdateLog(message) {
    global LogDisplay
    current := LogDisplay.Value
    newText := (current ? current "`n" : "") message
    
    lines := StrSplit(newText, "`n")
    if (lines.Length > 50) {
        newText := ""
        startIdx := lines.Length - 49
        loop (50) {
            idx := startIdx + A_Index - 1
            if (idx >= 1 && idx <= lines.Length) {
                newText .= lines[idx] "`n"
            }
        }
    }
    
    LogDisplay.Value := newText
}

OutputDebugString(message) {
    DllCall("kernel32\OutputDebugString", "str", message)
}

ToggleLogDisplay() {
    global LogDisplay, LogToggleButton, LogCollapsed, MyGUI
    
    if (LogCollapsed) {
        ; --- SAAT DIBUKA (EXPAND) ---
        LogDisplay.Visible := true
        LogToggleButton.Text := "v Detection Log"  
        LogCollapsed := 0
        MyGUI.Show("w800 h900")
    } else {
        LogDisplay.Visible := false
        LogToggleButton.Text := "> Detection Log"  
        LogCollapsed := 1
        MyGUI.Show("w800 h900") 
    }
}

return
