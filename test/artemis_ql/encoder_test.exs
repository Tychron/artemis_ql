defmodule ArtemisQL.EncoderTest do
  use ExUnit.Case

  describe "encode/1" do
    test "can encode a search list as a string" do
      assert {:ok, search_list, ""} =
        ArtemisQL.decode("""
        Term
        "Quoted Terms"
        a:1
        b:>2
        c:2022-09-07
        d:"Hello, \\"World\\""
        e:x,y,z
        f:"Aah","Bee","Cee"
        g:(A B C)
        h:@today
        i:H?llo
        j:"Abc "*" Xyz"
        k:Hello?Wor*
        l:X..Y
        m:"Take me".."To space"
        n:..B
        o:A..
        p:..
        x:null y:true z:false
        X:NULL Y:TRUE Z:FALSE
        w:^y
        """)

      assert {
        :ok,
        IO.iodata_to_binary(
          [
            "Term",
            "\"Quoted Terms\"",
            "a:1",
            "b:>2",
            "c:2022-09-07",
            "d:\"Hello, \\\"World\\\"\"",
            "e:x,y,z",
            "f:\"Aah\",\"Bee\",\"Cee\"",
            "g:(A B C)",
            "h:@today",
            "i:H?llo",
            "j:\"Abc \"*\" Xyz\"",
            "k:Hello?Wor*",
            "l:X..Y",
            "m:\"Take me\"..\"To space\"",
            "n:..B",
            "o:A..",
            "p:..",
            "x:NULL y:true z:false",
            "X:NULL Y:TRUE Z:FALSE",
            "w:^y",
          ]
          |> Enum.intersperse(" ")
        )
      } == ArtemisQL.encode(search_list)
    end
  end
end
