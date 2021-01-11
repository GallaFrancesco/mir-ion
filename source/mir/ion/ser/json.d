/++
$(H4 High level serialization API)

Macros:
IONREF = $(REF_ALTTEXT $(TT $2), $2, mir, ion, $1)$(NBSP)
+/
module mir.ion.ser.json;

/// JSON serialization back-end
struct JsonSerializer(string sep, Appender)
{
    import mir.bignum.decimal: Decimal;
    import mir.bignum.integer: BigInt;
    import std.traits: isNumeric;

    /// JSON string buffer
    Appender* appender;

    private uint state;

    static if(sep.length)
    {
        private size_t deep;

        private void putSpace()
        {
            for(auto k = deep; k; k--)
            {
                static if(sep.length == 1)
                {
                    appender.put(sep[0]);
                }
                else
                {
                    appender.put(sep);
                }
            }
        }
    }

    private void pushState(uint state)
    {
        this.state = state;
    }

    private uint popState()
    {
        auto ret = state;
        state = 0;
        return ret;
    }

    private void incState()
    {
        if(state++)
        {
            static if(sep.length)
            {
                appender.put(",\n");
            }
            else
            {
                appender.put(',');
            }
        }
    }

    private void putString(scope const char[] str)
    {
        import mir.utility: _expect;

        char[6] buffer = `\u0000`;
        size_t j;
        scope const(char)[] output;
        foreach (size_t i, char c; str)
        {
            if (_expect(c == '"', false))
            {
                output = `\"`;
            }
            else
            if (_expect(c == '\\', false))
            {
                output = `\\`;
            }
            else
            if (_expect(c < ' ', false))
            {
                if (c == '\t')
                {
                    output = `\t`;
                }
                else
                if (c == '\n')
                {
                    output = `\n`;
                }
                else
                if (c == '\r')
                {
                    output = `\r`;
                }
                else
                if (c == '\f')
                {
                    output = `\f`;
                }
                else
                if (c == '\b')
                {
                    output = `\b`;
                }
                else
                {
                    buffer[4] = cast(char)('0' + (c <= 0xF));
                    uint d = 0xF & c;
                    buffer[5] = cast(char)(d < 10 ? '0' + d : 'A' + (d - 10));
                    output = buffer;
                }
            }
            else
            if (_expect(i + 1 < str.length, true))
            {
                continue;
            }
            else
            {
                i += 1;
            }
            appender.put(str[j .. i]);
            appender.put(output);
            output = null;
            j = i + 1;
        }
    }

    /// Serialization primitives
    uint objectBegin()
    {
        static if(sep.length)
        {
            deep++;
            appender.put("{\n");
        }
        else
        {
            appender.put('{');
        }
        return popState;
    }

    ///ditto
    void objectEnd(uint state)
    {
        static if(sep.length)
        {
            deep--;
            appender.put('\n');
            putSpace;
        }
        appender.put('}');
        pushState(state);
    }

    ///ditto
    uint arrayBegin()
    {
        static if(sep.length)
        {
            deep++;
            appender.put("[\n");
        }
        else
        {
            appender.put('[');
        }
        return popState;
    }

    ///ditto
    void arrayEnd(uint state)
    {
        static if(sep.length)
        {
            deep--;
            appender.put('\n');
            putSpace;
        }
        appender.put(']');
        pushState(state);
    }

    ///ditto
    void putEscapedKey(scope const char[] key)
    {
        incState;
        static if(sep.length)
        {
            putSpace;
        }
        appender.put('\"');
        appender.put(key);
        static if(sep.length)
        {
            appender.put(`": `);
        }
        else
        {
            appender.put(`":`);
        }
    }

    ///ditto
    void putKey(scope const char[] key)
    {
        incState;
        static if(sep.length)
        {
            putSpace;
        }
        appender.put('\"');
        putString(key);
        static if(sep.length)
        {
            appender.put(`": `);
        }
        else
        {
            appender.put(`":`);
        }
    }

    ///ditto
    void putValue(Num)(Num num)
        if (isNumeric!Num && !is(Num == enum))
    {
        import mir.format: print;
        print(appender, num);
        return;
    }

    ///ditto
    void putValue(size_t size)(auto ref const BigInt!size num)
    {
        num.toString(appender);
    }

    ///ditto
    void putValue(size_t size)(auto ref const Decimal!size num)
    {
        num.toString(appender);
    }

    ///ditto
    void putValue(typeof(null))
    {
        appender.put("null");
    }

    ///ditto
    void putValue(bool b)
    {
        appender.put(b ? "true" : "false");
    }

    ///ditto
    void putEscapedValue(scope const char[] value)
    {
        appender.put('\"');
        appender.put(value);
        appender.put('\"');
    }

    ///ditto
    void putValue(scope const char[] value)
    {
        appender.put('\"');
        putString(value);
        appender.put('\"');
    }

    ///ditto
    void elemBegin()
    {
        incState;
        static if(sep.length)
        {
            putSpace;
        }
    }
}


/// JSON serialization function.
string serializeJson(V)(auto ref V value)
{
    return serializeJsonPretty!""(value);
}

///
unittest
{
    struct S
    {
        string foo;
        uint bar;
    }

    assert(serializeJson(S("str", 4)) == `{"foo":"str","bar":4}`);
}


/// JSON serialization function with pretty formatting.
string serializeJsonPretty(string sep = "\t", V)(auto ref V value)
{
    import std.array: appender;
    import std.functional: forward;

    auto app = appender!(char[]);
    serializeJsonPretty!sep(forward!value, app);
    return cast(string) app.data;
}

///
unittest
{
    static struct S { int a; }
    assert(S(4).serializeJsonPretty == "{\n\t\"a\": 4\n}");
}

/// JSON serialization function with pretty formatting and custom output range.
void serializeJsonPretty(string sep = "\t", V, Appender)(auto ref V value, ref Appender appender)
    // if (isOutputRange!(Appender, const(char)[]))
{
    import mir.ion.ser: serializeValue;
    auto ser = jsonSerializer!sep(&appender);
    ser.serializeValue(value);
}

///
unittest
{
    import mir.serde: serdeIgnoreDefault;

    static struct Decor
    {
        int candles; // 0
        float fluff = float.infinity; // inf 
    }
    
    static struct Cake
    {
        @serdeIgnoreDefault
        string name = "Chocolate Cake";
        int slices = 8;
        float flavor = 1;
        @serdeIgnoreDefault
        Decor dec = Decor(20); // { 20, inf }
    }
    
    assert(Cake("Normal Cake").serializeJson == `{"name":"Normal Cake","slices":8,"flavor":1.0}`);
    auto cake = Cake.init;
    cake.dec = Decor.init;
    assert(cake.serializeJson == `{"slices":8,"flavor":1.0,"dec":{"candles":0,"fluff":"inf"}}`);
    assert(cake.dec.serializeJson == `{"candles":0,"fluff":"inf"}`);
    
    static struct A
    {
        @serdeIgnoreDefault
        string str = "Banana";
        int i = 1;
    }
    assert(A.init.serializeJson == `{"i":1}`);
    
    static struct S
    {
        @serdeIgnoreDefault
        A a;
    }
    assert(S.init.serializeJson == `{}`);
    assert(S(A("Berry")).serializeJson == `{"a":{"str":"Berry","i":1}}`);
    
    static struct D
    {
        S s;
    }
    assert(D.init.serializeJson == `{"s":{}}`);
    assert(D(S(A("Berry"))).serializeJson == `{"s":{"a":{"str":"Berry","i":1}}}`);
    assert(D(S(A(null, 0))).serializeJson == `{"s":{"a":{"str":null,"i":0}}}`);
    
    static struct F
    {
        D d;
    }
    assert(F.init.serializeJson == `{"d":{"s":{}}}`);
}

///
unittest
{
    import mir.serde: serdeIgnoreIn;

    static struct S
    {
        @serdeIgnoreIn
        string s;
    }
    // assert(`{"s":"d"}`.deserializeJson!S.s == null, `{"s":"d"}`.deserializeJson!S.s);
    assert(S("d").serializeJson == `{"s":"d"}`);
}

///
unittest
{
    import mir.ion.deser;

    static struct S
    {
        @serdeIgnoreOut
        string s;
    }
    assert(`{"s":"d"}`.deserializeJson!S.s == "d");
    assert(S("d").serializeJson == `{}`);
}

///
unittest
{
    import mir.serde: serdeIgnoreOutIf;

    static struct S
    {
        @serdeIgnoreOutIf!`a < 0`
        int a;
    }

    assert(serializeJson(S(3)) == `{"a":3}`, serializeJson(S(3)));
    assert(serializeJson(S(-3)) == `{}`);
}

///
unittest
{
    import std.range;
    import std.uuid;
    import mir.serde: serdeIgnoreOut, serdeLikeList, serdeProxy;

    static struct S
    {
        private int count;
        @serdeLikeList
        auto numbers() @property // uses `foreach`
        {
            return iota(count);
        }

        @serdeLikeList
        @serdeProxy!string // input element type of
        @serdeIgnoreOut
        Appender!(string[]) strings; //`put` method is used
    }

    assert(S(5).serializeJson == `{"numbers":[0,1,2,3,4]}`);
    // assert(`{"strings":["a","b"]}`.deserializeJson!S.strings.data == ["a","b"]);
}

///
unittest
{
    import mir.serde: serdeLikeStruct, serdeProxy;

    static struct M
    {
        private int sum;

        // opApply is used for serialization
        int opApply(int delegate(scope const char[] key, int val) pure dg) pure
        {
            if(auto r = dg("a", 1)) return r;
            if(auto r = dg("b", 2)) return r;
            if(auto r = dg("c", 3)) return r;
            return 0;
        }

        // opIndexAssign for deserialization
        void opIndexAssign(int val, string key) pure
        {
            sum += val;
        }
    }

    static struct S
    {
        @serdeLikeStruct
        @serdeProxy!int
        M obj;
    }

    assert(S.init.serializeJson == `{"obj":{"a":1,"b":2,"c":3}}`);
    // assert(`{"obj":{"a":1,"b":2,"c":9}}`.deserializeJson!S.obj.sum == 12);
}

///
unittest
{
    import mir.ion.deser;
    import std.range;
    import std.algorithm;
    import std.conv;

    static struct S
    {
        @serdeTransformIn!"a += 2"
        @serdeTransformOut!(a =>"str".repeat.take(a).joiner("_").to!string)
        int a;
    }

    auto s = deserializeJson!S(`{"a":3}`);
    assert(s.a == 5);
    assert(serializeJson(s) == `{"a":"str_str_str_str_str"}`);
}

/++
Creates JSON serialization back-end.
Use `sep` equal to `"\t"` or `"    "` for pretty formatting.
+/
auto jsonSerializer(string sep = "", Appender)(return Appender* appender)
{
    return JsonSerializer!(sep, Appender)(appender);
}

///
unittest
{

    import std.array;
    import mir.bignum.integer;

    auto app = appender!string;
    auto ser = jsonSerializer(&app);
    auto state0 = ser.objectBegin;

        ser.putEscapedKey("null");
        ser.putValue(null);

        ser.putEscapedKey("array");
        auto state1 = ser.arrayBegin();
            ser.elemBegin; ser.putValue(null);
            ser.elemBegin; ser.putValue(123);
            ser.elemBegin; ser.putValue(12300000.123);
            ser.elemBegin; ser.putValue("\t");
            ser.elemBegin; ser.putValue("\r");
            ser.elemBegin; ser.putValue("\n");
            ser.elemBegin; ser.putValue(BigInt!2("1234567890"));
        ser.arrayEnd(state1);

    ser.objectEnd(state0);

    assert(app.data == `{"null":null,"array":[null,123,1.2300000123e7,"\t","\r","\n",1234567890]}`, app.data);
}

unittest
{
    import std.array;
    import mir.bignum.integer;

    auto app = appender!string;
    auto ser = jsonSerializer!"    "(&app);
    auto state0 = ser.objectBegin;

        ser.putEscapedKey("null");
        ser.putValue(null);

        ser.putEscapedKey("array");
        auto state1 = ser.arrayBegin();
            ser.elemBegin; ser.putValue(null);
            ser.elemBegin; ser.putValue(123);
            ser.elemBegin; ser.putValue(12300000.123);
            ser.elemBegin; ser.putValue("\t");
            ser.elemBegin; ser.putValue("\r");
            ser.elemBegin; ser.putValue("\n");
            ser.elemBegin; ser.putValue(BigInt!2("1234567890"));
        ser.arrayEnd(state1);

    ser.objectEnd(state0);

    assert(app.data ==
`{
    "null": null,
    "array": [
        null,
        123,
        1.2300000123e7,
        "\t",
        "\r",
        "\n",
        1234567890
    ]
}`);
}
