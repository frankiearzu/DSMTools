import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

public class DSM_Debug {
    public static String getText(int msgId) {
        switch (msgId) {
            case 0x0040: return "Roll"; 
            case 0x0041: return "Pitch";
            case 0x0042: return "Yaw";
            case 0x0043: return "Gain";
            case 0x0045: return "Differential";
            case 0x0046: return "Priority";
            case 0x0049: return "Output Setup";
        
            case 0x004A: return "Failsafe";
            case 0x004B: return "Main Menu";
            case 0x004E: return "Position";
        
            case 0x0050: return "Outputs";

            case 0x0071: return "Proportional";
            case 0x0072: return "Integral";
            case 0x0073: return "Derivate";
            case 0x0078: return "FM Channel";
            case 0x0080: return "Orientation";
            case 0x0086: return "System Setup";
            case 0x0087: return "F-Mode Setup";
            case 0x008B: return "Panic";

            case 0x0090: return "Apply";
            case 0x0093: return "Complete";

            case 0x00F9: return "Gyro Settings";
            
            case 0x00AD: return "Gain Channel Select";
            case 0x00CA: return "SAFE/Panic Mode Setup";
            case 0x00CD: return "Level model and capture attitude";

            case 0x00D3: return "Swashplate";
            case 0x00D5: return "Agility";
            case 0x00D8: return "Stop";
            case 0x00DA: return "SAFE";
            case 0x00DB: return "Stability";
            case 0x00DC: return "Deg. per sec";
            case 0x00DD: return "Tail rotor";
            case 0x0190: return "Relearn Model/Servo Settings (TX->RX)";
            case 0x01DC: return "AS3X"; 
            case 0x01DD: return "AS3X Settings";
            case 0x01E2: return "SAFE Settings";
            case 0x01E6: return "Attitude Trim";
            case 0x01EF: return "Low Thr to Pitch";
            case 0x01F0: return "High Thr to Pitch";

            case 0x01F8: return "SAFE Mode";

            case 0x0227: return "Other Settings";
            case 0x0240: return "Utilities";
            case 0x0267: return "Positive = Nose Up/Roll Right";
            case 0x0268: return "Negative = Nose Down/Roll Left";

            default: return String.format("Uknown_%04X",msgId);
        }
    }

    public static String func2String(int b1, int b2) {
        String s = "";
        if ((b2 & 0x01) > 0) s=s+"AIL(0x01) ";
        if ((b2 & 0x02) > 0) s=s+"ELE(0x02) ";
        if ((b2 & 0x04) > 0) s=s+"RUD(0x04) ";
        if ((b2 & 0x40) > 0) s=s+"THR(0x40) ";

        if ((b2 & 0x80) > 0) s=s+"Slave(0x80) ";
        if ((b2 & 0x20) > 0) s=s+"Rev(0x20) ";

        if (b1 > 0) s=s+String.format("B1?(0x%02X)",b1);

        return s;
    }

    public static byte[] StringHexToByte(String str) {
        if (!str.substring(0,2).equals("0x")) return new byte[0];

        byte[] result = new byte[(str.length()-2)/2];
        int p = 2;

        for (int i=0;i< result.length; i++) {
            String sb = str.substring(p,p+2);
            p+=2;
            result[i] = (byte) Integer.parseInt(sb,16);
        }

        return result;
    }

    public static String Byte2Hex(byte data[]) {
        String s = "";
        for (int i=0;i<data.length;i++) {
            s = s + String.format("%02X",data[i]) + " ";
        }
        return s;
    }

    public static String Byte2Text(byte data[]) {
        String s = "";
        for (int i=0;i<data.length;i++) {
            int c = data[i] & 0xFF;
            if (c< 32 || c> 127) {
                s = s + ".";
            } else {
                s = s + String.format("%c",data[i] & 0x7F);
            }
        }
        return s;
    }

    public static byte[] OutDataExtract(byte[] data) {
        int l = 0;
        byte[] out = new byte[6];

        int p = 4;
        for (int i=0;i<6;i++) {
            if (data[p] == 0x70 + i) {
                out[l++] = data[++p];
                p++;
            } else {
                out[l++] = (byte) 0xFF;
            }
        }
        return out;
    }

    public static byte[] InDataRXFwdProgExtract(byte[] data) {
        int l = 0;
        byte[] out = new byte[15];

        int p = 3;
        for (int i=0;i<15;i++) {
                out[l++] = data[p++];
        }
        return out;
    }



    static String parseTXFwrdProgMsg(byte[] data) {
        String r = "ERROR";

        switch (data[0]) {
            case 0x00: {
                r= String.format("TxHB");
                break;
            }
            case 0x11: {
                r= String.format("GetVersion()");
                break;
            }
            case 0x12: {
                r= String.format("GetMainMenu()");
                break;
            }
            case 0x13: {
                r= String.format("GetFirstMenuLine(0x%02X%02X)",data[2],data[3]);
                break;
            }
            case 0x14: {
                r= String.format("GetNextMenuLine(0x%02X%02X,L=%d)",data[2],data[3],data[5]);
                break;
            }
            case 0x15: {
                r= String.format("GetNextMenuValue(0x%02X%02X,0x%02X%02X)",data[2],data[3],data[4],data[5]);
                break;
            }
            case 0x16: {
                r= String.format("GetMenu(0x%02X%02X, 0x%02X L=%d)",
                        data[2],data[3],data[4],0xff&data[5]);
                break;
            }
            case 0x18: {
                r= String.format("UpdateMenuValue(0x%02X%02X,0x%02X%02X)",data[2],data[3],data[4],data[5]);
                break;
            }
            case 0x19: {
                r= String.format("ValidateMenuValue(0x%02X%02X)",data[2],data[3]);
                break;
            }
            case 0x1A: {
                r= String.format("MenuValueWait(Line=%d)",data[3]);
                break;
            }
            case 0x1B: {
                r= String.format("MenuValueWaitEND(Line=%d)",data[3]);
                break;
            }
            case 0x1F: {
                r= String.format("ExitRequest()");
                break;
            }
            case 0x20: {
                r= String.format("Send_TXChInfo_20(0x%02X 0x%02X 0x%02X 0x%02X)  P=%d %s",
                        data[2],data[3],data[4],data[5],
                        data[2],func2String(data[4],data[5]));
                break;
            }

            case 0x21: {
                r= String.format("Send_TXSubTrim_21(0x%02X 0x%02X 0x%02X 0x%02X)",
                        data[2],data[3],data[4],data[5]);
                break;
            }

            case 0x22: {
                r= String.format("Send_TXEnd_22(0x%02X 0x%02X)",
                        data[2],data[3]);
                break;
            }

            case 0x23: {
                r= String.format("Send_TXTravel_23(0x%02X 0x%02X 0x%02X 0x%02X)  Left=%d Right=%d",
                data[2],data[3],data[4],data[5],
                data[3],data[5]);
                break;
            }

            case 0x24: {
                r= String.format("Send_TX???_24(0x%02X 0x%02X 0x%02X 0x%02X)",
                data[2],data[3],data[4],data[5]);
                break;
            }



        }
        return r;
    }

    static String parseRXFwrdProgMsg(byte[] data) {
        String r="ERROR";
        switch (data[1]) {
            case 0x00: {
                r = String.format("RxHB");
                break;
            }
            case 0x01: {
                r = String.format("RX=0x%02X Version %d.%d.%d",
                        data[3],data[4],
                        data[5],data[6]);
                break;
            }
            case 0x02: {
                int tId = data[5]*256+ (data[4] & 0xFF);

                r = String.format("Menu[Mid=0x%02X%02X, Tid=0x%04X Text='%s']",
                        data[3],data[2],
                        tId,
                        getText(tId));
                break;
            }
            case 0x03: {
                int tId = data[7]*256+ (data[6] & 0xFF);

                r = String.format("MenuLine[Mid=0x%02X%02X, L=%d T=0x%02X Tid=0x%04X, Vid=0x%02X%02X Text='%s']",
                        data[3],data[2],
                        data[4],
                        data[5],
                        tId,
                        data[9],data[8],
                        getText(tId)
                        );
                break;
            }
            case 0x04: {
                r = String.format("MenuLineValue[Mid=0x%02X%02X, Vid=0x%02X%02X, Value=0x%02X%02X]",
                        data[3],data[2],
                        data[5],data[4],
                        data[7],data[6]
                );
                break;
            }
            case 0x05: {
                r = String.format("GetTxInfo[P=%d, Type=0x%02X]",
                        data[2],data[3]);
                break;
            }
        }
        return r;
    }


    static String parseTelemetryMsg(byte[] data) {
        String r="TELEMETRY";

        byte i2cId=data[3];

        switch (i2cId) {
            case 0x0C:  { // TextGen
                byte sid = data[4];
                byte lineNo = data[5];
                String msg = "";
                for (int i=0;i<13;i++) {
                    if (data[6+i]==0) break;
                    msg = msg + String.format("%c",data[6+i]);
                }

                r = String.format("TextGen(0x0C) sId=%d Line#=%02d Msg=\"%s\"", sid,lineNo,msg);
                break;
            }

            default: {
                byte sid = data[4];
                r = String.format("Tel: i2C_addr=%02X sId=%d",i2cId,sid);
            }
            

        }

        return r;
    }


    public static void processFile(String fileName) {
        BufferedReader reader;

        try {
            reader = new BufferedReader(new FileReader(fileName));
            String line = reader.readLine();

            while (line != null) {
                String[] fields = line.split(",");
                if (fields.length < 5) break;

                byte[] inData = StringHexToByte(fields[4]);
                byte[] outData = StringHexToByte(fields[5]);

                //System.out.println(fields[4]);
                if (inData.length > 5 && inData[3]==0x09) {  // TEL-ID=0x09 = Forward Programming
                    byte[] rxMsg = InDataRXFwdProgExtract(inData);
                    String debugMsg = parseRXFwrdProgMsg(rxMsg);
                    System.out.println("RX: "+Byte2Hex(rxMsg)+ " | "+debugMsg);
                } else
                if (inData.length > 4) { // Other Telemetry Data
                        byte[] rxMsg = inData;
                        //String debugMsg = parseTelemetryMsg(rxMsg);
                       //System.out.println("RX: "+Byte2Hex(rxMsg)+ " | "+debugMsg);
                }

                //System.out.println(fields[5]);
                if (outData.length > 5 && outData[4]==0x70) {
                    byte[] txMsg= OutDataExtract(outData);
                    String debugMsg = parseTXFwrdProgMsg(txMsg);
                    System.out.println("TX: "+Byte2Hex(txMsg)+String.format("%27s","")+" | "+debugMsg);
                }

                // read next line
                line = reader.readLine();
            }

            reader.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage DSM_Debug <filename> ");
        } else {
            processFile(args[0]);
        }
    }
}