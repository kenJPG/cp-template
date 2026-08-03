import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

public class {{CLASS_NAME}} {
    private static void solve(BufferedReader reader, StringBuilder out) throws IOException {
        
    }

    public static void main(String[] args) throws Exception {
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        StringBuilder out = new StringBuilder();
        int testCases = 1;
        // testCases = Integer.parseInt(reader.readLine().trim());

        while (testCases-- > 0) {
            solve(reader, out);
        }
        System.out.print(out);
    }
}
