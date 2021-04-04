using System;
using System.Collections.Generic;

namespace LookupGenerator
{
    class Program
    {
        static Dictionary<int, int> dictOdd;
        static Dictionary<int, int> dictOddC;
        static Dictionary<int, int> dictEven;
        static Dictionary<int, int> dictEvenC;

        static void Main(string[] args)
        {
            dictOdd = new Dictionary<int, int>();
            dictOddC = new Dictionary<int, int>();
            dictEven = new Dictionary<int, int>();
            dictEvenC = new Dictionary<int, int>();

            BuildLUTs();
            //OddEvenColorByte(false, false);
            //TestColorByte();
            BuildOddEvenLUT(false,true);
            //YMulWidth();
        }

        static void BuildLUTs()
        {
            //odd byte no carry
            dictOdd.Add(3, 3);    //00000011
            dictOdd.Add(6, 12);    //00000110 to 00001100
            dictOdd.Add(7, 3);    //00000111 to 00000011
            //dictOdd.Add(11, 11);    //00001011
            //dictOdd.Add(12, 12);    //00001100
            //dictOdd.Add(13, 13);    //00001101
            dictOdd.Add(14, 12);    //00001110 to 00001100
            //dictOdd.Add(15, 15);    //00001111
            //dictOdd.Add(19, 19);    //00010011
            dictOdd.Add(22, 28);    //00010110 to 00011100
            //dictOdd.Add(23, 23);    //00010111
            dictOdd.Add(24, 48);    //00011000 to 00110000
            dictOdd.Add(25, 49);    //00011001 to 00110001
            dictOdd.Add(26, 50);    //00011010 to 00110010
            dictOdd.Add(27, 59);    //00011011 to 00111011
            dictOdd.Add(28, 12);    //00011100 to 00001100
            dictOdd.Add(29, 13);    //00011101 to 00001101
            dictOdd.Add(30, 60);    //00011110 to 00111100
            dictOdd.Add(31, 15);    //00011111 to 00001111
            //dictOdd.Add(35, 35);    //00100011
            dictOdd.Add(38, 44);    //00100110 to 00101100 preserve 7th bit for even byte
            dictOdd.Add(39, 35);    //00100111 to 00100011
            //dictOdd.Add(43, 43);    //00101011
            //dictOdd.Add(44, 44);    //00101100
            //dictOdd.Add(45, 45);    //00101101
            dictOdd.Add(46, 44);    //00101110 to 00101100
            //dictOdd.Add(47, 47);    //00101111
            //dictOdd.Add(48, 48);    //00110000
            //dictOdd.Add(49, 49);    //00110001
            //dictOdd.Add(50, 50);    //00110010
            //dictOdd.Add(51, 51);    //00110011
            //dictOdd.Add(52, 52);    //00110100
            //dictOdd.Add(53, 53);    //00110101
            dictOdd.Add(54, 55);    //00110110 to 00110111 preserve 7th bit
            //dictOdd.Add(55, 55);    //00110111
            dictOdd.Add(56, 48);    //00111000 to 00110000
            dictOdd.Add(57, 49);    //00111001 to 00110001
            dictOdd.Add(58, 56);    //00111010 to 00111000
            //dictOdd.Add(59, 59);    //00111011
            //dictOdd.Add(60, 60);    //00111100
            //dictOdd.Add(61, 61);    //00111101
            dictOdd.Add(62, 60);    //00111110 to 00111100
            //dictOdd.Add(63, 63);    //00111111
            //dictOdd.Add(67, 67);    //01000011
            dictOdd.Add(70, 76);    //01000110 to 01001100
            dictOdd.Add(71, 67);    //01000111 to 01000011
            //dictOdd.Add(75, 75);    //01001011
            //dictOdd.Add(76, 76);    //01001100
            //dictOdd.Add(77, 77);    //01001101
            dictOdd.Add(78, 76);    //01001110 to 01001100
            //dictOdd.Add(79, 79);    //01001111
            //dictOdd.Add(83, 83);    //01010011
            dictOdd.Add(86, 92);    //01010110 to 01011100
            //dictOdd.Add(87, 87);    //01010111
            dictOdd.Add(88, 112);    //01011000 to 01110000
            dictOdd.Add(89, 113);    //01011001 to 01110001
            dictOdd.Add(90, 116);    //01011010 to 01110100
            dictOdd.Add(91, 123);    //01011011 to 01111011
            //dictOdd.Add(92, 92);    //01011100
            //dictOdd.Add(93, 93);    //01011101
            dictOdd.Add(94, 124);    //01011110 to 01111100
            dictOdd.Add(95, 127);    //01011111 to 01111111
            dictOdd.Add(96, 112);    //01100000 to 01110000
            dictOdd.Add(97, 113);    //01100001 to 01110001
            dictOdd.Add(98, 114);    //01100010 to 01110010
            dictOdd.Add(99, 115);    //01100011 to 01110011
            dictOdd.Add(100, 116);    //01100100 to 01110100
            dictOdd.Add(101, 117);    //01100101 to 01110101 ?
            dictOdd.Add(102, 115);    //01100110 to 01110011
            dictOdd.Add(103, 115);    //01100111 to 01110011
            dictOdd.Add(104, 120);    //01101000 to 01111000
            dictOdd.Add(105, 121);    //01101001 to 01111001
            dictOdd.Add(106, 122);    //01101010 to 01111010
            dictOdd.Add(107, 123);    //01101011 to 01111011
            dictOdd.Add(108, 124);    //01101100 to 01111100 ?
            dictOdd.Add(109, 125);    //01101101 to 01111101
            dictOdd.Add(110, 119);    //01101110 to 01110111
            dictOdd.Add(111, 119);    //01101111 to 01110111
            //dictOdd.Add(112, 112);    //01110000
            //dictOdd.Add(113, 113);    //01110001
            //dictOdd.Add(114, 114);    //01110010
            //dictOdd.Add(115, 115);    //01110011
            //dictOdd.Add(116, 116);    //01110100
            //dictOdd.Add(117, 117);    //01110101
            dictOdd.Add(118, 119);    //01110110 to 01110111
            //dictOdd.Add(119, 119);    //01110111
            dictOdd.Add(120, 124);    //01111000 to 01111100
            dictOdd.Add(121, 113);    //01111001 to 01110001
            dictOdd.Add(122, 126);    //01111010 to 01111110
            //dictOdd.Add(123, 123);    //01111011
            //dictOdd.Add(124, 124);    //01111100
            //dictOdd.Add(125, 125);    //01111101
            dictOdd.Add(126, 126);    //01111110 to 01111100
            //dictOdd.Add(127, 127);    //01111111

            //odd byte with carry
            //dictOddC.Add(0, 0);    //00000000
            dictOddC.Add(1, 3);    //00000001 to 00000011
            //dictOddC.Add(2, 2);    //00000010
            dictOddC.Add(3, 3);    //00000011 or possibly 00001111
            //dictOddC.Add(4, 4);    //00000100
            dictOddC.Add(5, 7);    //00000101 to 00000111
            dictOddC.Add(6, 14);    //00000110 to 00001110
            dictOddC.Add(7, 15);    //00000111 to 00001111
            //dictOddC.Add(8, 8);    //00001000
            dictOddC.Add(9, 11);    //00001001 to 00001011
            //dictOddC.Add(10, 10);    //00001010
            //dictOddC.Add(11, 11);    //00001011
            //dictOddC.Add(12, 12);    //00001100
            dictOddC.Add(13, 15);    //00001101 to 00001111 had to get rid of magenta artifact
            //dictOddC.Add(14, 14);    //00001110
            //dictOddC.Add(15, 15);    //00001111
            //dictOddC.Add(16, 16);    //00010000
            //dictOddC.Add(17, 17);    //00010001
            //dictOddC.Add(18, 18);    //00010010
            //dictOddC.Add(19, 19);    //00010011
            //dictOddC.Add(20, 20);    //00010100
            dictOddC.Add(21, 23);    //00010101 to 00010111
            dictOddC.Add(22, 30);    //00010110 to 00011110
            dictOddC.Add(23, 31);    //00010111 to 00011111
            dictOddC.Add(24, 48);    //00011000 to 00110000
            dictOddC.Add(25, 51);    //00011001 to 00110011
            dictOddC.Add(26, 58);    //00011010 to 00111010
            dictOddC.Add(27, 59);    //00011011 to 00111011
            dictOddC.Add(28, 12);    //00011100 to 00001100
            dictOddC.Add(29, 55);    //00011101 to 00110111 magenta artifact
            dictOddC.Add(30, 62);    //00011110 to 00111110
            dictOddC.Add(31, 63);    //00011111 to 00111111
            //dictOddC.Add(32, 32);    //00100000
            dictOddC.Add(33, 35);    //00100001 to 00100011
            //dictOddC.Add(34, 34);    //00100010
            //dictOddC.Add(35, 35);    //00100011
            //dictOddC.Add(36, 36);    //00100100
            dictOddC.Add(37, 39);    //00100101 to 00100111
            dictOddC.Add(38, 46);    //00100110 to 00101110
            dictOddC.Add(39, 35);    //00100111 to 00100011
            //dictOddC.Add(40, 40);    //00101000
            dictOddC.Add(41, 35);    //00101001 to 00100011
            //dictOddC.Add(42, 42);    //00101010
            //dictOddC.Add(43, 43);    //00101011
            //dictOddC.Add(44, 44);    //00101100
            dictOddC.Add(45, 47);    //00101101 to 00101111  had to take out magenta artifact
            //dictOddC.Add(46, 46);    //00101110
            //dictOddC.Add(47, 47);    //00101111
            //dictOddC.Add(48, 48);    //00110000
            dictOddC.Add(49, 51);    //00110001 to 00110011
            //dictOddC.Add(50, 50);    //00110010
            //dictOddC.Add(51, 51);    //00110011
            //dictOddC.Add(52, 52);    //00110100
            dictOddC.Add(53, 55);    //00110101 to 00110111
            dictOddC.Add(54, 62);    //00110110 to 00111110 took out magenta artifact
            //dictOddC.Add(55, 55);    //00110111
            dictOddC.Add(56, 48);    //00111000 to 00110000 took out half white pixel
            dictOddC.Add(57, 51);    //00111001 to 00110011
            //dictOddC.Add(58, 58);    //00111010
            //dictOddC.Add(59, 59);    //00111011
            //dictOddC.Add(60, 60);    //00111100
            dictOddC.Add(61, 63);    //00111101 to 00111111 took out magenta artifact
            //dictOddC.Add(62, 62);    //00111110
            //dictOddC.Add(63, 63);    //00111111
            //dictOddC.Add(64, 64);    //01000000
            //dictOddC.Add(65, 65);    //01000001
            //dictOddC.Add(66, 66);    //01000010
            //dictOddC.Add(67, 67);    //01000011
            //dictOddC.Add(68, 68);    //01000100
            dictOddC.Add(69, 71);    //01000101 to 01000111
            dictOddC.Add(70, 78);    //01000110 to 01001110
            dictOddC.Add(71, 67);    //01000111 to 01000011
            //dictOddC.Add(72, 72);    //01001000
            dictOddC.Add(73, 75);    //01001001 to 01001011
            //dictOddC.Add(74, 74);    //01001010
            //dictOddC.Add(75, 75);    //01001011
            //dictOddC.Add(76, 76);    //01001100
            dictOddC.Add(77, 79);    //01001101 to 01001111 took out magenta artifact
            //dictOddC.Add(78, 78);    //01001110
            //dictOddC.Add(79, 79);    //01001111
            //dictOddC.Add(80, 80);    //01010000
            dictOddC.Add(81, 83);    //01010001 to 01010011
            //dictOddC.Add(82, 82);    //01010010
            //dictOddC.Add(83, 83);    //01010011
            //dictOddC.Add(84, 84);    //01010100
            dictOddC.Add(85, 87);    //01010101 to 01010111
            dictOddC.Add(86, 94);    //01010110 to 01011110
            //dictOddC.Add(87, 87);    //01010111
            dictOddC.Add(88, 92);    //01011000 to 01011100
            dictOddC.Add(89, 115);    //01011001 to 01110011
            dictOddC.Add(90, 122);    //01011010 to 01111010
            dictOddC.Add(91, 123);    //01011011 to 01111011 green artifact
            //dictOddC.Add(92, 92);    //01011100
            dictOddC.Add(93, 119);    //01011101 to 01110111 magenta artifact
            //dictOddC.Add(94, 94);    //01011110
            //dictOddC.Add(95, 95);    //01011111
            dictOddC.Add(96, 112);    //01100000 to 01110000
            dictOddC.Add(97, 115);    //01100001 to 01110011
            dictOddC.Add(98, 114);    //01100010 to 01110010
            dictOddC.Add(99, 115);    //01100011 to 01110011
            dictOddC.Add(100, 116);    //01100100 to 01110100
            dictOddC.Add(101, 119);    //01100101 to 01110111 took out black pixel
            dictOddC.Add(102, 126);    //01100110 to 01111110
            dictOddC.Add(103, 115);    //01100111 to 01110011
            dictOddC.Add(104, 120);    //01101000 to 01111000
            dictOddC.Add(105, 123);    //01101001 to 01111011
            dictOddC.Add(106, 122);    //01101010 to 01111010
            dictOddC.Add(107, 123);    //01101011 to 01111011
            dictOddC.Add(108, 124);    //01101100 to 01111100 took out green artifact
            dictOddC.Add(109, 127);    //01101101 to 01111111 took out magenta and green artifact
            dictOddC.Add(110, 126);    //01101110 to 01111110 took out green artifact
            dictOddC.Add(111, 127);    //01101111 to 01111111 took out green artifact
            //dictOddC.Add(112, 112);    //01110000
            dictOddC.Add(113, 115);    //01110001 to 01110011
            //dictOddC.Add(114, 114);    //01110010
            //dictOddC.Add(115, 115);    //01110011
            //dictOddC.Add(116, 116);    //01110100
            dictOddC.Add(117, 119);    //01110101 to 01110111
            dictOddC.Add(118, 126);    //01110110 to 01111110 took out magenta artifact
            //dictOddC.Add(119, 119);    //01110111
            dictOddC.Add(120, 124);    //01111000 to 01111100
            dictOddC.Add(121, 115);    //01111001 to 01110011
            //dictOddC.Add(122, 122);    //01111010
            //dictOddC.Add(123, 123);    //01111011
            //dictOddC.Add(124, 124);    //01111100
            dictOddC.Add(125, 127);    //01111101 to 01111111 took out magenta artifact
            //dictOddC.Add(126, 126);    //01111110
            //dictOddC.Add(127, 127);    //01111111

            //even byte no carry
            dictEven.Add(3, 7);    //00000011 to 00000111
            //dictEven.Add(6, 6);    //00000110
            //dictEven.Add(7, 7);    //00000111 
            dictEven.Add(11, 15);    //00001011 to 00001111
            dictEven.Add(12, 24);    //00001100 to 00011000
            dictEven.Add(13, 29);    //00001101 to 00011101
            dictEven.Add(14, 6);    //00001110 to 00000110
            dictEven.Add(15, 31);    //00001111 to 00011111
            dictEven.Add(19, 71);    //00010011 to 01000111 for even byte I can manipulate 7th bit if needed!
            //dictEven.Add(22, 22);    //00010110
            //dictEven.Add(23, 23);    //00010111
            //dictEven.Add(24, 24);    //00011000 
            //dictEven.Add(25, 25);    //00011001
            //dictEven.Add(26, 26);    //00011010
            dictEven.Add(27, 31);    //00011011 to 00011111
            dictEven.Add(28, 24);    //00011100 to 00011000
            //dictEven.Add(29, 29);    //00011101
            //dictEven.Add(30, 30);    //00011110
            //dictEven.Add(31, 31);    //00011111 
            dictEven.Add(35, 39);    //00100011 to 00100111
            //dictEven.Add(38, 38);    //00100110
            //dictEven.Add(39, 39);    //00100111
            dictEven.Add(43, 47);    //00101011 to 00101111
            dictEven.Add(44, 56);    //00101100 to 00111000
            dictEven.Add(45, 61);    //00101101 to 00111101
            //dictEven.Add(46, 46);    //00101110
            dictEven.Add(47, 63);    //00101111 to 00111111
            dictEven.Add(48, 96);    //00110000 to 01100000
            dictEven.Add(49, 97);    //00110001 to 01100001
            dictEven.Add(50, 98);    //00110010 to 01100010
            dictEven.Add(51, 103);    //00110011 to 01100111
            dictEven.Add(52, 116);    //00110100 to 01110100
            dictEven.Add(53, 117);    //00110101 to 01110101
            dictEven.Add(54, 118);    //00110110 to 01110110 green artifact
            dictEven.Add(55, 119);    //00110111 to 01110111 green artifact
            dictEven.Add(56, 24);    //00111000 to 00011000
            dictEven.Add(57, 25);    //00111001 to 00011001
            dictEven.Add(58, 26);    //00111010 to 00011010
            dictEven.Add(59, 111);    //00111011 to 01101111 magenta artifact
            dictEven.Add(60, 120);    //00111100 to 01111000
            dictEven.Add(61, 125);    //00111101 to 01111101
            dictEven.Add(62, 30);    //00111110 to 00011110
            dictEven.Add(63, 31);    //00111111 to 00011111
            dictEven.Add(67, 71);    //01000011 to 01000111
            //dictEven.Add(70, 70);    //01000110
            //dictEven.Add(71, 71);    //01000111
            dictEven.Add(75, 79);    //01001011 to 01001111
            dictEven.Add(76, 88);    //01001100 to 01011000
            dictEven.Add(77, 93);    //01001101 to 01011101
            dictEven.Add(78, 70);    //01001110 to 01000110
            dictEven.Add(79, 71);    //01001111 to 01000111
            dictEven.Add(83, 87);    //01010011 to 01010111
            //dictEven.Add(86, 86);    //01010110
            //dictEven.Add(87, 87);    //01010111
            //dictEven.Add(88, 88);    //01011000
            //dictEven.Add(89, 89);    //01011001
            //dictEven.Add(90, 90);    //01011010
            dictEven.Add(91, 95);    //01011011 to 01011111 took out magenta artifact
            dictEven.Add(92, 88);    //01011100 to 01011000
            //dictEven.Add(93, 93);    //01011101
            //dictEven.Add(94, 94);    //01011110
            //dictEven.Add(95, 95);    //01011111
            //dictEven.Add(96, 96);    //01100000
            //dictEven.Add(97, 97);    //01100001
            //dictEven.Add(98, 98);    //01100010
            dictEven.Add(99, 103);    //01100011 to 01100111
            //dictEven.Add(100, 100);    //01100100
            //dictEven.Add(101, 101);    //01100101
            //dictEven.Add(102, 102);    //01100110
            //dictEven.Add(103, 103);    //01100111
            //dictEven.Add(104, 104);    //01101000
            //dictEven.Add(105, 105);    //01101001
            //dictEven.Add(106, 106);    //01101010
            dictEven.Add(107, 111);    //01101011 to 01101111
            dictEven.Add(108, 120);    //01101100 to 01111000 took out magenta artifact
            dictEven.Add(109, 125);    //01101101 to 01111101 took out magenta artifact
            //dictEven.Add(110, 110);    //01101110
            //dictEven.Add(111, 111);    //01101111
            dictEven.Add(112, 96);    //01110000 to 01100000
            dictEven.Add(113, 97);    //01110001 to 01100001
            dictEven.Add(114, 98);    //01110010 to 01100010
            dictEven.Add(115, 103);    //01110011 to 01100111
            //dictEven.Add(116, 116);    //01110100
            //dictEven.Add(117, 117);    //01110101
            //dictEven.Add(118, 118);    //01110110
            //dictEven.Add(119, 119);    //01110111
            //dictEven.Add(120, 120);    //01111000
            //dictEven.Add(121, 121);    //01111001
            //dictEven.Add(122, 122);    //01111010
            dictEven.Add(123, 127);    //01111011 to 01111111 took out magenta artifact
            dictEven.Add(124, 120);    //01111100 to 01111000
            //dictEven.Add(125, 125);    //01111101
            //dictEven.Add(126, 126);    //01111110
            //dictEven.Add(127, 127);    //01111111

            
        }

        static void TestColorByte()
        {
            for (int i = 0; i < 256; i++)
            {
                var toHex = i.ToString("X2");
                //toHex = "00";
                Console.WriteLine($"                        byte    ${toHex}  ");
            }

        }

        static void BuildOddEvenLUT(bool is_odd = true, bool carry = false)
        {
            var dict = new Dictionary<int, int>();

            for (int i = 0; i < 128; i++)
            {
                var current_byte = i;
                //if byte contains two adjacent bits, flag it
                int white_mask = 3; //0000_0011
                bool found_white = false;
                

                for (int y = 0; y < 6; y++)
                {
                    if ((current_byte & white_mask) == 3)
                    {
                        //white pixel found, flag byte
                        found_white = true;
                    }

                    current_byte >>= 1;
                }

                if (found_white || (carry))
                {
                    //add to dictionary
                    dict.Add(i, i); 
                }

            }
            
            Console.WriteLine(dict.Count);
            var dictName = "dict";
            if (is_odd)
                dictName += "Odd";
            else
                dictName += "Even";

            if (carry)
                dictName += "C";

            foreach (var num in dict)
            {
                Console.WriteLine($"{dictName}.Add({num.Key}, {num.Value});    //{Convert.ToString(num.Value, 2).PadLeft(8, '0')}");
            }
             
        }


        static void OddEvenColorByte(bool is_odd = true, bool carry = false)
        {
            //loop from 0 to 256
            //display in format below
            //                        byte    $00      '0 (00)

            for (int i = 0; i < 256; i++)
            {
                //get first 7 bits and see if there's a replacement in dictOdd
                //if yes then update from dictionary
                //else use initial value
                var bit_mask = 127; //01111111
                var current_byte = i;
                var first_seven = i & bit_mask;
                var is_modified = false;
                var dict = is_odd ? (carry ? dictOddC : dictOdd) : (carry ? dictEvenC : dictEven);

                if (dict.ContainsKey(first_seven))
                {
                    is_modified = true;
                    var modified = dict[first_seven];
                    //clear bits first
                    current_byte &= ~first_seven;
                    //then or in modified bits
                    current_byte |= modified;
                }

                var toHex = current_byte.ToString("X2");
                var toBin = Convert.ToString(current_byte, 2).PadLeft(8, '0');
                var originalBin = Convert.ToString(i, 2).PadLeft(8, '0');

                Console.WriteLine($"                        byte    ${toHex}      '{current_byte} ({toBin}) {(is_modified ? "modified from " + i.ToString("X2") + " (" + originalBin + ")" : "")}");

            }
        }
     

        static void YMulWidth()
        {
            //loop from 0 to 192
            //multiply num by 320
            //display in format below
            //                        byte    $00, $00      '0 (0)
            //                        byte    $01, $20      '1 (288)


            for (int i = 0; i < 193; i++)
            {
                var multBy = i * 320;
                var toHex = multBy.ToString("X4");

                Console.WriteLine($"                        byte    ${toHex.Substring(0, 2)}, ${toHex.Substring(2, 2)}      '{i} ({multBy})");

            }
        }
    }
}
