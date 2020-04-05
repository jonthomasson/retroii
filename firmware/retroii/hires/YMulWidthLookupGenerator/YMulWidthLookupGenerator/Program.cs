using System;

namespace YMulWidthLookupGenerator
{
    class Program
    {
        static void Main(string[] args)
        {
           
            //loop from 0 to 192
            //multiply num by 288
            //display in format below
            //                        byte    $00, $00      '0 (0)
            //                        byte    $01, $20      '1 (288)


            for(int i = 0; i < 193; i++)
            {
                var multBy = i * 288;
                var toHex = multBy.ToString("X4");

                Console.WriteLine($"                        byte    ${toHex.Substring(0,2)}, ${toHex.Substring(2, 2)}      '{i} ({multBy})");
                
            }
        }
    }
}
